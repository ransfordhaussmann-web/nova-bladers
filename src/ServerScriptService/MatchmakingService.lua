local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local MODE_IDS = { "training", "pvp", "ffa" }

local queues = {}
local playerQueue = {}
local fillTimers = {}
local remotes
local matchReady
local leaveHubForArena
local getRecommendedMode

local function initQueues()
	for _, modeId in MODE_IDS do
		queues[modeId] = {}
	end
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = queues[modeId] or {}
	local queueSize = #queue
	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	end

	local secondsLeft
	local timer = fillTimers[modeId]
	if timer and timer.deadline then
		secondsLeft = math.max(0, math.ceil(timer.deadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = queueSize,
		requiredPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		secondsLeft = secondsLeft,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
end

local function broadcastQueueUpdates(modeId)
	for _, queuedPlayer in queues[modeId] or {} do
		if queuedPlayer.Parent then
			sendQueueUpdate(queuedPlayer)
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
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)

	if fillTimers[modeId] and #queue == 0 then
		fillTimers[modeId] = nil
	end
end

local function cancelFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	local token = (fillTimers[modeId] and fillTimers[modeId].token or 0) + 1
	local deadline = os.clock() + mode.fillTimeout
	fillTimers[modeId] = { token = token, deadline = deadline }

	task.delay(mode.fillTimeout, function()
		local timer = fillTimers[modeId]
		if not timer or timer.token ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)

	broadcastQueueUpdates(modeId)
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local players = {}
	for _ = 1, count do
		local player = table.remove(queue, 1)
		if not player then
			break
		end
		playerQueue[player] = nil
		table.insert(players, player)
	end
	return players
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return
	end

	local queue = queues[modeId]
	if not queue or #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout > 0 then
		if #queue >= mode.maxPlayers then
			cancelFillTimer(modeId)
		elseif fillTimers[modeId] then
			return
		else
			startFillTimer(modeId)
			return
		end
	end

	local takeCount = math.min(#queue, mode.maxPlayers)
	local matchPlayers = popPlayers(modeId, takeCount)

	for _, player in matchPlayers do
		if not player.Parent then
			takeCount -= 1
		end
	end

	local validPlayers = {}
	for _, player in matchPlayers do
		if player.Parent then
			table.insert(validPlayers, player)
		end
	end

	if #validPlayers < mode.minPlayers then
		for _, player in validPlayers do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		broadcastQueueUpdates(modeId)
		return
	end

	for _, player in validPlayers do
		sendQueueUpdate(player)
		if leaveHubForArena then
			leaveHubForArena(player)
		end
	end

	broadcastQueueUpdates(modeId)
	matchReady:Fire({
		players = validPlayers,
		mode = modeId,
	})
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.onArenaFreed()
	for _, modeId in MODE_IDS do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(options)
	remotes = options.remotes
	matchReady = options.bindables.MatchReady
	leaveHubForArena = options.leaveHubForArena
	getRecommendedMode = options.getRecommendedMode

	initQueues()

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = getRecommendedMode and getRecommendedMode() or MatchmakingConfig.DEFAULT_MODE
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId, queue in queues do
				if #queue > 0 and fillTimers[modeId] then
					broadcastQueueUpdates(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
