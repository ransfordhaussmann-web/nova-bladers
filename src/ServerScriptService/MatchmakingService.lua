--[[
	MatchmakingService — Queue pro Modus, startet Matches via MatchReady-Bindable.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local remotes = nil
local MatchReady = nil
local getPhase = nil
local leaveHubForArena = nil
local initialized = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId] = nil
	end
end

local function getQueueCount(modeId)
	return #(queues[modeId] or {})
end

local function buildUpdateForPlayer(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif mode.fillTimeout and #queue >= mode.minPlayers then
		status = "filling"
	end

	local fillRemaining = nil
	if fillTimers[modeId] then
		fillRemaining = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		label = mode.label,
		desc = mode.desc,
		status = status,
		position = position,
		playersInQueue = #queue,
		requiredPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueueUpdate()
	if not remotes then
		return
	end

	for player in pairs(playerQueue) do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildUpdateForPlayer(player))
		end
	end
end

local function sendQueueUpdate(player)
	if not remotes or not player.Parent then
		return
	end
	remotes.QueueUpdate:FireClient(player, buildUpdateForPlayer(player))
end

local function clearQueueUpdate(player)
	if not remotes or not player.Parent then
		return
	end
	remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or #queue < mode.minPlayers then
		return false
	end
	if #queue >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout and fillTimers[modeId] then
		return os.clock() >= fillTimers[modeId].endsAt
	end
	return mode.minPlayers == mode.maxPlayers
end

local function popPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(matchPlayers, player)
			playerQueue[player] = nil
		end
	end

	fillTimers[modeId] = nil
	return matchPlayers
end

local function preparePlayersForMatch(matchPlayers)
	for _, player in matchPlayers do
		if getPhase(player) ~= "arena" then
			leaveHubForArena(player)
		end
	end
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout and #queue >= mode.minPlayers and #queue < mode.maxPlayers then
		if not fillTimers[modeId] then
			fillTimers[modeId] = { endsAt = os.clock() + mode.fillTimeout }
			broadcastQueueUpdate()
		end
	end

	if not canStartMode(modeId) then
		return
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers < mode.minPlayers then
		for _, player in matchPlayers do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		return
	end

	MatchStateService.setArenaBusy(true)
	preparePlayersForMatch(matchPlayers)
	broadcastQueueUpdate()

	for _, player in matchPlayers do
		clearQueueUpdate(player)
	end

	MatchReady:Fire(matchPlayers, modeId)
end

local function tryAllQueues()
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if getPhase(player) == "arena" then
		return false, "already_in_arena"
	end
	if MatchStateService.isArenaBusy() and not playerQueue[player] then
		-- Erlaubt join trotzdem — Spieler wartet als pending
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	sendQueueUpdate(player)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	clearQueueUpdate(player)
	broadcastQueueUpdate()

	if fillTimers[modeId] and getQueueCount(modeId) < MatchModes.get(modeId).minPlayers then
		fillTimers[modeId] = nil
	end

	return true
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(tryAllQueues)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init(deps)
	if initialized then
		return
	end
	initialized = true

	remotes = deps.remotes
	MatchReady = deps.MatchReady
	getPhase = deps.getPhase
	leaveHubForArena = deps.leaveHubForArena

	initQueues()

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			if not MatchStateService.isArenaBusy() then
				tryAllQueues()
			end
			broadcastQueueUpdate()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
