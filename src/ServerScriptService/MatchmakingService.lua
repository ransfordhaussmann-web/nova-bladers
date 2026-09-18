local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local fillStartedAt = {}
local fillTickers = {}

local function ensureQueues()
	for _, mode in MatchModes do
		if not queues[mode.id] then
			queues[mode.id] = {}
		end
	end
end

local function getQueueCount(modeId)
	return #(queues[modeId] or {})
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = queues[modeId]
	local count = #queue
	local position = 1
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local fillRemaining
	if mode.fillTimeout and fillStartedAt[modeId] then
		local elapsed = os.clock() - fillStartedAt[modeId]
		fillRemaining = math.max(0, math.ceil(mode.fillTimeout - elapsed))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = MatchStateService.isBusy(),
		fillRemaining = fillRemaining,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
end

local function broadcastQueue(modeId)
	for _, queuedPlayer in queues[modeId] or {} do
		if queuedPlayer.Parent then
			sendQueueUpdate(queuedPlayer)
		end
	end
end

local function stopFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
	if fillTickers[modeId] then
		task.cancel(fillTickers[modeId])
		fillTickers[modeId] = nil
	end
	fillStartedAt[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end
	if fillTimers[modeId] then
		return
	end

	fillStartedAt[modeId] = os.clock()
	broadcastQueue(modeId)

	fillTickers[modeId] = task.spawn(function()
		while fillStartedAt[modeId] do
			task.wait(MatchmakingConfig.FILL_TICK_INTERVAL)
			if fillStartedAt[modeId] then
				broadcastQueue(modeId)
			end
		end
	end)

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		fillStartedAt[modeId] = nil
		if fillTickers[modeId] then
			task.cancel(fillTickers[modeId])
			fillTickers[modeId] = nil
		end

		local count = getQueueCount(modeId)
		if count >= mode.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

local function removeFromQueue(player, modeId, broadcast)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if playerQueue[player] == modeId then
		playerQueue[player] = nil
	end

	local mode = MatchModes.get(modeId)
	if mode and getQueueCount(modeId) < mode.minPlayers then
		stopFillTimer(modeId)
	end

	if broadcast then
		broadcastQueue(modeId)
	end
end

function MatchmakingService.leaveQueue(player, broadcast)
	local modeId = playerQueue[player]
	if not modeId then
		if broadcast then
			sendQueueUpdate(player)
		end
		return
	end

	removeFromQueue(player, modeId, broadcast ~= false)
	if broadcast ~= false then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if HubService.getPhase(player) == "arena" then
		return false
	end

	MatchmakingService.leaveQueue(player, false)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)

	local mode = MatchModes.get(modeId)
	if getQueueCount(modeId) >= mode.minPlayers and mode.fillTimeout then
		startFillTimer(modeId)
	end

	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return
	end
	if count < mode.maxPlayers and mode.fillTimeout and fillTimers[modeId] then
		return
	end
	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local queue = queues[modeId]
	local playerList = {}
	local take = math.min(count, mode.maxPlayers)
	for index = 1, take do
		table.insert(playerList, queue[index])
	end

	stopFillTimer(modeId)

	for _, matchedPlayer in playerList do
		removeFromQueue(matchedPlayer, modeId, false)
		Remotes.QueueUpdate:FireClient(matchedPlayer, { inQueue = false })
	end

	broadcastQueue(modeId)

	for _, matchedPlayer in playerList do
		if matchedPlayer.Parent and HubService.getPhase(matchedPlayer) == "hub" then
			HubService.leaveHubForArena(matchedPlayer)
		end
	end

	MatchReady:Fire(playerList, modeId)
end

function MatchmakingService.processPendingQueues()
	for _, mode in MatchModes do
		if getQueueCount(mode.id) >= mode.minPlayers then
			MatchmakingService.tryStartMatch(mode.id)
		end
	end
end

function MatchmakingService.init(hubHandlers)
	ensureQueues()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	if hubHandlers and hubHandlers.leaveHubForArena then
		HubService.register({
			returnToHub = hubHandlers.returnToHub,
			getPhase = hubHandlers.getPhase,
			leaveHubForArena = hubHandlers.leaveHubForArena,
		})
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingConfig.recommendMode(#Players:GetPlayers())
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player, false)
	end)

	MatchStateService.onArenaFreed(function()
		MatchmakingService.processPendingQueues()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
