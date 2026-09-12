local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerEntry = {}
local ffaFillStartedAt = nil
local pendingLaunch = {}
local running = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function queueSize(modeId)
	local queue = queues[modeId]
	return queue and #queue or 0
end

local function findQueueIndex(modeId, player)
	local queue = queues[modeId]
	if not queue then
		return nil
	end
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function buildQueuePayload(player, modeId)
	local mode = getModeConfig(modeId)
	local index = findQueueIndex(modeId, player) or 1

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = index,
		queueSize = queueSize(modeId),
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		pending = pendingLaunch[player] == true,
		inQueue = playerEntry[player] == modeId,
	}
end

local function broadcastQueue(player)
	local modeId = playerEntry[player]
	if not modeId or not Remotes then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
end

local function broadcastAllInMode(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, queuedPlayer in queue do
		broadcastQueue(queuedPlayer)
	end
end

local function removeFromQueue(player)
	local modeId = playerEntry[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	local index = findQueueIndex(modeId, player)
	if queue and index then
		table.remove(queue, index)
	end

	playerEntry[player] = nil
	pendingLaunch[player] = nil

	if modeId == "ffa" and queueSize("ffa") < MatchmakingConfig.MODES.ffa.minPlayers then
		ffaFillStartedAt = nil
	end

	broadcastAllInMode(modeId)
end

local function markPending(players)
	for _, player in players do
		pendingLaunch[player] = true
		broadcastQueue(player)
	end
end

local function popPlayers(modeId, count)
	local mode = getModeConfig(modeId)
	if not mode then
		return {}
	end

	local queue = queues[modeId]
	if not queue then
		return {}
	end

	local picked = {}
	local nextQueue = {}

	for _, player in queue do
		if #picked < count and player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(picked, player)
		else
			table.insert(nextQueue, player)
		end
	end

	queues[modeId] = nextQueue
	for _, player in picked do
		playerEntry[player] = nil
		pendingLaunch[player] = nil
	end

	broadcastAllInMode(modeId)
	return picked
end

local function notifyLeftQueue(player)
	if Remotes then
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			modeId = nil,
		})
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end
	removeFromQueue(player)
	notifyLeftQueue(player)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	if playerEntry[player] then
		if playerEntry[player] == modeId then
			broadcastQueue(player)
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	if not queues[modeId] then
		queues[modeId] = {}
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = modeId
	pendingLaunch[player] = nil

	if modeId == "ffa" and queueSize("ffa") >= MatchmakingConfig.MODES.ffa.minPlayers and not ffaFillStartedAt then
		ffaFillStartedAt = os.clock()
	end

	broadcastAllInMode(modeId)
	return true
end

local function canStartFFA()
	local mode = MatchmakingConfig.MODES.ffa
	local size = queueSize("ffa")
	if size >= mode.maxPlayers then
		return true, mode.maxPlayers
	end
	if size >= mode.minPlayers and ffaFillStartedAt then
		if os.clock() - ffaFillStartedAt >= mode.fillTimeout then
			return true, size
		end
	end
	return false
end

local function tryLaunchMode(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local size = queueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	local launchCount = mode.maxPlayers
	if modeId == "ffa" then
		local ready, count = canStartFFA()
		if not ready then
			return
		end
		launchCount = count
	else
		if size < mode.maxPlayers then
			return
		end
	end

	if GameMatchState.isBusy() then
		local queue = queues[modeId]
		if queue then
			markPending(queue)
		end
		return
	end

	local players = popPlayers(modeId, launchCount)
	if #players < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		ffaFillStartedAt = nil
	end

	for _, player in players do
		HubService.leaveHubForMatch(player)
	end

	Bindables.MatchReady:Fire(players, modeId)
end

local function tickQueues()
	if not running then
		return
	end

	for modeId in MatchmakingConfig.MODES do
		tryLaunchMode(modeId)
	end
end

function MatchmakingService.onArenaFree()
	for _, player in Players:GetPlayers() do
		if pendingLaunch[player] and playerEntry[player] then
			pendingLaunch[player] = nil
			broadcastQueue(player)
		end
	end
	task.defer(tickQueues)
end

function MatchmakingService.getPreferredMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start()
	if running then
		return
	end

	Remotes, Bindables = RemotesSetup.ensure()

	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getPreferredMode()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	running = true
	task.spawn(function()
		while running do
			tickQueues()
			task.wait(MatchmakingConfig.QUEUE_TICK)
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
