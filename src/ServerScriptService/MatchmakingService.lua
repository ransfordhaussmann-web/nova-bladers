local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local matchReadyBindable
local queues = {}
local playerMode = {}
local fillTimers = {}
local tickLoopStarted = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function buildStatusText(mode, queued, status)
	if status == "pending" then
		return "Arena belegt — Warte auf freies Match..."
	end
	if status == "starting" then
		return "Match startet..."
	end
	if queued >= mode.maxPlayers then
		return string.format("%d/%d — Start bereit", queued, mode.maxPlayers)
	end
	if mode.minPlayers <= 1 then
		return "Suche Gegner..."
	end
	if queued < mode.minPlayers then
		return string.format("Warte auf Spieler (%d/%d)", queued, mode.minPlayers)
	end
	if mode.fillTimeout then
		return string.format("Warte auf weitere (%d/%d)", queued, mode.maxPlayers)
	end
	return string.format("%d/%d Spieler", queued, mode.maxPlayers)
end

local function sendQueueUpdate(player)
	if not remotes or not remotes.QueueUpdate then
		return
	end

	local modeId = playerMode[player]
	if not modeId then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local queued = getQueueSize(modeId)
	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queued = queued,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		statusText = buildStatusText(mode, queued, status),
	})
end

local function broadcastQueueUpdates(modeId)
	for _, queuedPlayer in queues[modeId] or {} do
		if queuedPlayer.Parent then
			sendQueueUpdate(queuedPlayer)
		end
	end
end

local function broadcastAllQueueUpdates()
	for modeId in queues do
		broadcastQueueUpdates(modeId)
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for index, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, index)
				break
			end
		end
	end

	playerMode[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	if not silent then
		sendQueueUpdate(player)
	end
	broadcastQueueUpdates(modeId)
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, count do
		local nextPlayer = table.remove(queue, 1)
		if not nextPlayer then
			break
		end
		playerMode[nextPlayer] = nil
		table.insert(picked, nextPlayer)
	end
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	for _, queuedPlayer in playerList do
		sendQueueUpdate(queuedPlayer)
	end
	broadcastQueueUpdates(modeId)

	if matchReadyBindable then
		matchReadyBindable:Fire({
			modeId = modeId,
			players = playerList,
		})
	end
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue then
		return false
	end

	local queued = #queue
	if queued < mode.minPlayers then
		return false
	end

	if mode.instantStart or queued >= mode.maxPlayers then
		local count = math.min(queued, mode.maxPlayers)
		local players = popPlayers(modeId, count)
		startMatch(modeId, players)
		return true
	end

	if mode.fillTimeout and queued >= mode.minPlayers and not fillTimers[modeId] then
		fillTimers[modeId] = task.delay(mode.fillTimeout, function()
			fillTimers[modeId] = nil
			if MatchStateService.isBusy() then
				return
			end
			local currentQueue = queues[modeId]
			if not currentQueue or #currentQueue < mode.minPlayers then
				return
			end
			local count = math.min(#currentQueue, mode.maxPlayers)
			local players = popPlayers(modeId, count)
			startMatch(modeId, players)
		end)
	end

	return false
end

local function processQueues()
	for modeId in queues do
		tryStartMode(modeId)
	end
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

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerMode[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerMode[player] == modeId then
		sendQueueUpdate(player)
		return true
	end

	removeFromQueue(player, true)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	processQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		sendQueueUpdate(player)
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.removePlayer(player)
	removeFromQueue(player, true)
end

function MatchmakingService.init(remoteFolder, bindables)
	remotes = remoteFolder
	matchReadyBindable = bindables.MatchReady
	initQueues()

	if tickLoopStarted then
		return
	end
	tickLoopStarted = true

	MatchStateService.onArenaFree(function()
		broadcastAllQueueUpdates()
		processQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			processQueues()
		end
	end)

	if remotes.QueueJoin then
		remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
			if typeof(modeId) ~= "string" then
				modeId = MatchmakingService.getRecommendedModeId()
			end
			MatchmakingService.joinQueue(player, modeId)
		end)
	end

	if remotes.QueueLeave then
		remotes.QueueLeave.OnServerEvent:Connect(function(player)
			MatchmakingService.leaveQueue(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.removePlayer(player)
	end)
end

return MatchmakingService
