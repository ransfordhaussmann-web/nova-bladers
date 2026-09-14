local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady
local ArenaFree

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if fillTimers[entry.modeId] then
		fillTimers[entry.modeId] = nil
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(player, status)
	local entry = playerQueue[player]
	if not entry then
		return { status = "idle" }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		status = status or entry.status,
		modeId = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		position = position,
		queued = #queue,
		required = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		arenaBusy = GameMatchState.isArenaBusy(),
	}
end

local function sendQueueUpdate(player, status)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, status))
	end
end

local function broadcastQueueUpdates(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		sendQueueUpdate(queuedPlayer)
	end
end

local function leaveHubForArena(player, leaveHub)
	if leaveHub then
		leaveHub(player)
	end
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerQueue[player] = nil
		end
	end
	return picked
end

local function tryStartMatch(modeId, leaveHub)
	if GameMatchState.isArenaBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	local playerCount = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		for _, player in players do
			playerQueue[player] = { modeId = modeId, status = "queued" }
			table.insert(getQueue(modeId), player)
		end
		return false
	end

	fillTimers[modeId] = nil
	GameMatchState.setArenaBusy(true)

	for _, player in players do
		leaveHubForArena(player, leaveHub)
		sendQueueUpdate(player, "starting")
	end

	broadcastQueueUpdates(modeId)
	MatchReady:Fire(players, modeId)
	return true
end

local function scheduleFillTimeout(modeId, leaveHub)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId, leaveHub)
	end)
end

local function evaluateQueue(modeId, leaveHub)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if GameMatchState.isArenaBusy() then
		for _, queuedPlayer in queue do
			local entry = playerQueue[queuedPlayer]
			if entry then
				entry.status = "pending"
				sendQueueUpdate(queuedPlayer, "pending")
			end
		end
		return
	end

	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId, leaveHub)
		return
	end

	if mode.fillTimeout then
		for _, queuedPlayer in queue do
			local entry = playerQueue[queuedPlayer]
			if entry then
				entry.status = "waiting"
				sendQueueUpdate(queuedPlayer, "waiting")
			end
		end
		scheduleFillTimeout(modeId, leaveHub)
	else
		tryStartMatch(modeId, leaveHub)
	end
end

local function onArenaFree(leaveHub)
	for modeId, _ in MatchModes.all() do
		evaluateQueue(modeId, leaveHub)
	end
end

function MatchmakingService.joinQueue(player, modeId, leaveHub)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	removeFromQueue(player)

	local status = if GameMatchState.isArenaBusy() then "pending" else "queued"
	playerQueue[player] = { modeId = modeId, status = status }
	table.insert(getQueue(modeId), player)

	sendQueueUpdate(player, status)
	broadcastQueueUpdates(modeId)
	evaluateQueue(modeId, leaveHub)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player, "idle")
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	sendQueueUpdate(player, "idle")
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.getQueueInfo(player)
	return buildQueuePayload(player)
end

function MatchmakingService.start(options)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	ArenaFree = Bindables.ArenaFree

	local leaveHub = options and options.leaveHub

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId, leaveHub)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(function()
		onArenaFree(leaveHub)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for player, _ in playerQueue do
				if player.Parent then
					sendQueueUpdate(player)
				end
			end
		end
	end)
end

return MatchmakingService
