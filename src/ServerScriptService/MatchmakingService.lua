local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady
local ArenaFree

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	local count = 0
	for _, player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId] or {}
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	local pendingArena = GameMatchState.isArenaBusy()
	local status = pendingArena and "pending" or "waiting"

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #names,
		maxPlayers = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		status = status,
		pendingArena = pendingArena,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil
	broadcastQueueUpdate(modeId)
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end
	if fillTimers[modeId] then
		return
	end

	local token = os.clock()
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	local remaining = {}

	for _, player in queue do
		if player.Parent and #taken < count then
			table.insert(taken, player)
			playerQueue[player] = nil
		else
			table.insert(remaining, player)
		end
	end

	queues[modeId] = remaining
	return taken
end

function MatchmakingService.tryStartMatch(modeId)
	if GameMatchState.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	local playerCount = math.min(size, mode.maxPlayers)
	local players = takePlayersFromQueue(modeId, playerCount)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	clearFillTimer(modeId)
	GameMatchState.setArenaBusy(true)

	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			status = "starting",
			inQueue = false,
		})
	end

	MatchReady:Fire(players, modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false, "invalid_mode"
	end
	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end
	if playerQueue[player] == modeId then
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	local size = getQueueSize(modeId)

	broadcastQueueUpdate(modeId)

	if size >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif size >= mode.minPlayers and not mode.fillTimeout then
		MatchmakingService.tryStartMatch(modeId)
	elseif size >= mode.minPlayers and mode.fillTimeout then
		startFillTimer(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	local modeId = playerQueue[player]
	removeFromQueue(player)

	local mode = MatchModes.get(modeId)
	if mode and getQueueSize(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
	end

	Remotes.QueueUpdate:FireClient(player, {
		inQueue = false,
		status = "left",
	})
end

function MatchmakingService.joinRecommended(player)
	local count = #Players:GetPlayers()
	local modeId = MatchModes.recommendForPlayerCount(count)
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaBusy(false)
	for _, mode in MatchModes.getAll() do
		if getQueueSize(mode.id) >= mode.minPlayers then
			if mode.fillTimeout and getQueueSize(mode.id) < mode.maxPlayers then
				startFillTimer(mode.id)
			else
				MatchmakingService.tryStartMatch(mode.id)
			end
		else
			broadcastQueueUpdate(mode.id)
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	ArenaFree = Bindables.ArenaFree

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" and modeId ~= "" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinRecommended(player)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
