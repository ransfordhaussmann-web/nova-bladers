local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil
local started = false

local Remotes
local MatchReady
local ArenaFree
local tryStartMatch

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getPlayerNames(playerList)
	local names = {}
	for _, player in playerList do
		table.insert(names, player.Name)
	end
	return names
end

local function buildQueuePayload(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if GameMatchState.isArenaBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		position = position,
		total = #queue,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		players = getPlayerNames(queue),
		pendingArena = GameMatchState.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue == 0 then
		clearFillTimer(modeId)
	end

	if player.Parent and Remotes then
		Remotes.QueueUpdate:FireClient(player, { status = "left" })
	end

	broadcastQueueUpdate(modeId)
end

local function canStartMode(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count >= mode.maxPlayers then
		return true
	end

	return count >= mode.minPlayers
end

local function onFillTimeout(modeId)
	fillTimers[modeId] = nil
	local queue = getQueue(modeId)
	if modeId == "ffa" and #queue >= 2 then
		tryStartMatch(modeId, true)
		return
	end
	if canStartMode(modeId) then
		tryStartMatch(modeId, false)
	end
end

local function takePlayersForMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for i = 1, count do
		local player = queue[i]
		table.insert(matchPlayers, player)
		playerQueue[player] = nil
	end

	for i = 1, count do
		table.remove(queue, 1)
	end

	clearFillTimer(modeId)
	broadcastQueueUpdate(modeId)

	return matchPlayers
end

tryStartMatch = function(modeId, forceStart)
	if GameMatchState.isArenaBusy() then
		pendingMatch = modeId
		broadcastQueueUpdate(modeId)
		return
	end

	if not forceStart and not canStartMode(modeId) then
		return
	end

	local queue = getQueue(modeId)
	if forceStart and modeId == "ffa" and #queue < 2 then
		return
	end

	local matchPlayers = takePlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return
	end

	pendingMatch = nil

	for _, player in matchPlayers do
		if HubService.getPhase(player) == "hub" then
			HubService.leaveHubForArena(player)
		end
	end

	MatchReady:Fire(matchPlayers, modeId)
end

local function scheduleFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if mode.fillTimeout <= 0 or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		onFillTimeout(modeId)
	end)
end

local function joinQueue(player, modeId)
	if not MatchmakingConfig.getMode(modeId) then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue >= MatchmakingConfig.getMode(modeId).maxPlayers then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(modeId)

	local mode = MatchmakingConfig.getMode(modeId)
	if mode.fillTimeout > 0 and #queue < mode.minPlayers and not fillTimers[modeId] then
		scheduleFillTimer(modeId)
	end

	tryStartMatch(modeId)
end

local function onArenaFree()
	if pendingMatch then
		local modeId = pendingMatch
		pendingMatch = nil
		tryStartMatch(modeId)
		return
	end

	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start(remotes, bindables)
	if started then
		return
	end
	started = true

	Remotes = remotes
	MatchReady = bindables.MatchReady
	ArenaFree = bindables.ArenaFree

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			modeId = MatchmakingConfig.resolveAutoMode(#Players:GetPlayers())
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		removeFromQueue(player)
	end)

	ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)
end

return MatchmakingService
