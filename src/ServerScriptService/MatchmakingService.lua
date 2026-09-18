local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local fillActive = {}
local fillStartedAt = {}
local pendingModes = {}
local onMatchStart

local function initQueues()
	for modeId in MatchModes do
		queues[modeId] = {}
		fillTokens[modeId] = 0
		fillActive[modeId] = false
		fillStartedAt[modeId] = nil
		pendingModes[modeId] = false
	end
end

local function getQueueCount(modeId)
	return #(queues[modeId] or {})
end

local function getFillSecondsRemaining(modeId)
	local mode = MatchModes[modeId]
	if not mode or mode.fillTimeout <= 0 then
		return nil
	end
	if getQueueCount(modeId) < mode.minPlayers then
		return nil
	end
	if not fillActive[modeId] or not fillStartedAt[modeId] then
		return nil
	end
	local elapsed = os.clock() - fillStartedAt[modeId]
	return math.max(0, math.ceil(mode.fillTimeout - elapsed))
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes[modeId]
	local count = getQueueCount(modeId)
	local pending = pendingModes[modeId] or MatchStateService.isBusy()

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		fillSeconds = getFillSecondsRemaining(modeId),
	}
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			sendQueueUpdate(player)
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] += 1
	fillActive[modeId] = false
	fillStartedAt[modeId] = nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if getQueueCount(modeId) < MatchModes[modeId].minPlayers then
		cancelFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates()
end

local function takePlayersFromQueue(modeId)
	local mode = MatchModes[modeId]
	local queue = queues[modeId]
	local taken = {}
	local takeCount = math.min(#queue, mode.maxPlayers)

	for i = 1, takeCount do
		local player = queue[i]
		table.insert(taken, player)
		playerQueue[player] = nil
	end

	for i = 1, takeCount do
		table.remove(queue, 1)
	end

	cancelFillTimer(modeId)
	pendingModes[modeId] = false
	broadcastQueueUpdates()

	return taken
end

local function startMatch(modeId)
	local mode = MatchModes[modeId]
	if not mode then
		return
	end

	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		pendingModes[modeId] = true
		broadcastQueueUpdates()
		return
	end

	local players = takePlayersFromQueue(modeId)
	if #players < mode.minPlayers then
		return
	end

	MatchStateService.setBusy(true)

	if onMatchStart then
		onMatchStart(players, modeId)
	end

	if MatchReady then
		MatchReady:Fire(players, modeId)
	end
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes[modeId]
	if not mode or mode.fillTimeout <= 0 then
		startMatch(modeId)
		return
	end

	fillTokens[modeId] += 1
	local token = fillTokens[modeId]
	fillActive[modeId] = true
	fillStartedAt[modeId] = os.clock()

	task.delay(mode.fillTimeout, function()
		fillActive[modeId] = false
		fillStartedAt[modeId] = nil
		if token ~= fillTokens[modeId] then
			return
		end
		if getQueueCount(modeId) >= mode.minPlayers then
			startMatch(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes[modeId]
	if not mode then
		return
	end

	local count = getQueueCount(modeId)

	if count >= mode.maxPlayers then
		startMatch(modeId)
		return
	end

	if modeId == "training" and count >= 1 then
		startMatch(modeId)
		return
	end

	if modeId == "pvp" and count >= 2 then
		startMatch(modeId)
		return
	end

	if modeId == "ffa" and count >= mode.minPlayers and not fillActive[modeId] then
		scheduleFillTimer(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes[modeId] then
		return false
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return true
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	sendQueueUpdate(player)
	broadcastQueueUpdates()
	evaluateQueue(modeId)

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player)
		return
	end
	removeFromQueue(player)
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
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFree()
	for modeId in MatchModes do
		if pendingModes[modeId] or getQueueCount(modeId) > 0 then
			pendingModes[modeId] = false
			evaluateQueue(modeId)
		end
	end
end

function MatchmakingService.init(options)
	initQueues()

	Remotes = options.remotes
	MatchReady = options.matchReady
	onMatchStart = options.onMatchStart

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "auto" then
			modeId = MatchmakingService.getRecommendedModeId()
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
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			broadcastQueueUpdates()
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
