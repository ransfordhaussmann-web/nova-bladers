local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local broadcastLoop = nil

for _, mode in MatchModes.all() do
	queues[mode.id] = {}
end

local function getQueueSize(modeId)
	return #queues[modeId]
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
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function getQueuePosition(player, modeId)
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = getQueuePosition(player, modeId)
	local queueSize = #queue
	local message

	if status == "pending" then
		message = "Arena belegt — du bist in der Warteschlange"
	elseif queueSize >= mode.minPlayers then
		message = string.format("Match startet bald (%d/%d)", queueSize, mode.maxPlayers)
	else
		message = string.format("Warte auf Spieler (%d/%d)", queueSize, mode.minPlayers)
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = queueSize,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		message = message,
		arenaBusy = GameMatchState.isArenaBusy(),
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates()
	for modeId, queue in queues do
		local status = if GameMatchState.isArenaBusy() then "pending" else "waiting"
		for _, player in queue do
			sendQueueUpdate(player, buildQueuePayload(player, modeId, status))
		end
	end
end

local function clearQueue(modeId)
	queues[modeId] = {}
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function startMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		playerQueue[player] = nil
		sendQueueUpdate(player, { inQueue = false })
		HubService.leaveHubForArena(player)
	end

	clearQueue(modeId)
	GameMatchState.setArenaBusy(true)
	Bindables.MatchReady:Fire(matchPlayers)

	for modeId2, remainingQueue in queues do
		for _, player in remainingQueue do
			sendQueueUpdate(player, buildQueuePayload(player, modeId2, "pending"))
		end
	end
end

local function tryStartMatch(modeId)
	if GameMatchState.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout <= 0 or #queue >= mode.maxPlayers then
		startMatch(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		if not GameMatchState.isArenaBusy() and #queues[modeId] >= mode.minPlayers then
			startMatch(modeId)
		end
	end)
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)

	local queue = queues[modeId]
	if #queue >= MatchModes.get(modeId).maxPlayers then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	local status = if GameMatchState.isArenaBusy() then "pending" else "waiting"
	sendQueueUpdate(player, buildQueuePayload(player, modeId, status))
	tryStartMatch(modeId)
end

local function leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player, { inQueue = false })
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	sendQueueUpdate(player, { inQueue = false })
	broadcastQueueUpdates()
	tryStartMatch(modeId)
end

local function onArenaFree()
	GameMatchState.setArenaBusy(false)
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
	broadcastQueueUpdates()
end

function MatchmakingService.start(remotes, bindables)
	Remotes = remotes
	Bindables = bindables

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(onArenaFree)

	if broadcastLoop then
		task.cancel(broadcastLoop)
	end
	broadcastLoop = task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastQueueUpdates()
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

return MatchmakingService
