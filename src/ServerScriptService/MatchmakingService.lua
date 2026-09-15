local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local callbacks = {}
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function isPlayerAvailable(player)
	if not player or not player.Parent then
		return false
	end
	if callbacks.isPlayerAvailable then
		return callbacks.isPlayerAvailable(player)
	end
	return true
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
end

local function getQueueStatus(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = getQueue(modeId)
	local count = 0
	for _, player in queue do
		if isPlayerAvailable(player) then
			count += 1
		end
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif count >= mode.minPlayers then
		status = "starting"
	end

	local fillTimeLeft = nil
	if mode.fillTimeout and fillTimers[modeId] then
		fillTimeLeft = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queuedCount = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeLeft = fillTimeLeft,
	}
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end

	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local status = getQueueStatus(modeId)
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		modeId = status.modeId,
		modeLabel = status.modeLabel,
		queuedCount = status.queuedCount,
		minPlayers = status.minPlayers,
		maxPlayers = status.maxPlayers,
		status = status.status,
		fillTimeLeft = status.fillTimeLeft,
	})
end

local function broadcastQueueUpdates(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		sendQueueUpdate(player)
	end
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local cleaned = {}
	for _, player in queue do
		if isPlayerAvailable(player) then
			table.insert(cleaned, player)
		else
			playerQueue[player] = nil
		end
	end
	queues[modeId] = cleaned
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	pruneQueue(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return nil
	end

	local ready = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(ready, queue[i])
	end
	return ready
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
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

	local token = { cancelled = false, endsAt = os.clock() + mode.fillTimeout }
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if token.cancelled or fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function finalizeMatchStart(modeId, readyPlayers)
	clearFillTimer(modeId)
	queues[modeId] = {}

	for _, player in readyPlayers do
		playerQueue[player] = nil
		sendQueueUpdate(player)
	end

	MatchStateService.setBusy()

	if callbacks.onMatchReady then
		callbacks.onMatchReady(readyPlayers, modeId)
	end

	Bindables.MatchReady:Fire({
		players = readyPlayers,
		modeId = modeId,
	})
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		broadcastQueueUpdates(modeId)
		return false
	end

	local readyPlayers = collectReadyPlayers(modeId)
	if not readyPlayers then
		return false
	end

	task.delay(MatchmakingConfig.START_DELAY, function()
		if MatchStateService.isBusy() then
			broadcastQueueUpdates(modeId)
			return
		end

		local players = collectReadyPlayers(modeId)
		if not players then
			return
		end

		finalizeMatchStart(modeId, players)
	end)

	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not isPlayerAvailable(player) then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)

	if #queue >= mode.minPlayers and not MatchStateService.isBusy() then
		if mode.fillTimeout and #queue < mode.maxPlayers then
			startFillTimer(modeId)
		else
			MatchmakingService.tryStartMatch(modeId)
		end
	elseif mode.fillTimeout and #queue >= mode.minPlayers then
		startFillTimer(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	sendQueueUpdate(player)

	local mode = MatchModes.get(modeId)
	if mode and getQueue(modeId) and #getQueue(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdates(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setIdle()
	for modeId in queues do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.start(options)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	callbacks = options or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			if callbacks.getQuickMatchMode then
				modeId = callbacks.getQuickMatchMode()
			else
				return
			end
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		for modeId in queues do
			MatchmakingService.tryStartMatch(modeId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId in fillTimers do
				broadcastQueueUpdates(modeId)
			end
		end
	end)
end

return MatchmakingService
