local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local fillEndsAt = {}
local processing = false

local function initQueues()
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {}
	end
end

local function getQueueCount(modeId)
	return #(queues[modeId] or {})
end

local function buildUpdatePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif mode.useFillTimer and getQueueCount(modeId) >= mode.minPlayers and fillEndsAt[modeId] then
		status = "filling"
	elseif getQueueCount(modeId) >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = getQueueCount(modeId),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillEndsAt = fillEndsAt[modeId],
		position = nil,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local payload = buildUpdatePayload(modeId, player)
	if not payload then
		return
	end

	payload.inQueue = true
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			payload.position = i
			break
		end
	end

	Remotes.QueueUpdate:FireClient(player, payload)
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	playerQueue[player] = nil

	if getQueueCount(modeId) < MatchModes.get(modeId).minPlayers then
		fillEndsAt[modeId] = nil
		if fillTimers[modeId] then
			task.cancel(fillTimers[modeId])
			fillTimers[modeId] = nil
		end
	end

	broadcastQueueUpdate(modeId)
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.useFillTimer and fillEndsAt[modeId] and Workspace:GetServerTimeNow() >= fillEndsAt[modeId] then
		return true
	end
	return false
end

local function popPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local players = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(players, player)
		end
	end

	fillEndsAt[modeId] = nil
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	return players
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.useFillTimer or fillTimers[modeId] then
		return
	end

	fillEndsAt[modeId] = Workspace:GetServerTimeNow() + MatchmakingConfig.FFA_FILL_TIMEOUT
	fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers[modeId] = nil
		fillEndsAt[modeId] = nil
		MatchmakingService.tryStartMatches()
	end)

	broadcastQueueUpdate(modeId)
end

local function launchMatch(modeId, playerList)
	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		HubService.leaveHubForArena(player)
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

function MatchmakingService.tryStartMatches()
	if processing or MatchStateService.isArenaBusy() then
		return
	end

	processing = true

	for _, mode in MatchModes.getAll() do
		if canStartMode(mode.id) then
			local players = popPlayersForMatch(mode.id)
			if #players > 0 then
				launchMatch(mode.id, players)
				processing = false
				return
			end
		end
	end

	processing = false
end

function MatchmakingService.onArenaFree()
	MatchStateService.setArenaBusy(false)
	task.defer(MatchmakingService.tryStartMatches)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	if mode.useFillTimer and getQueueCount(modeId) >= mode.minPlayers then
		startFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
	MatchmakingService.tryStartMatches()
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.ARENA_BUSY_RETRY)
			if not MatchStateService.isArenaBusy() then
				MatchmakingService.tryStartMatches()
			else
				for _, mode in MatchModes.getAll() do
					broadcastQueueUpdate(mode.id)
				end
			end
		end
	end)
end

return MatchmakingService
