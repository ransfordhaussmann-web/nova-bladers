local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local queueJoinTime = {}
local matchIdle = true
local gatherTokens = {}
local initialized = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueueList(queue, player)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function getQueueCounts()
	return {
		training = #queues.training,
		pvp = #queues.pvp,
		ffa = #queues.ffa,
	}
end

local function buildStatusForPlayer(player)
	local modeId = playerQueue[player]
	if not modeId then
		return {
			queued = false,
			mode = nil,
			position = 0,
			playersInQueue = 0,
			requiredPlayers = 0,
			queueCounts = getQueueCounts(),
		}
	end

	local queue = queues[modeId]
	local config = getModeConfig(modeId)
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		queued = true,
		mode = modeId,
		modeLabel = config.label,
		position = position,
		playersInQueue = #queue,
		requiredPlayers = config.minPlayers,
		queueCounts = getQueueCounts(),
	}
end

local function sendQueueStatus(player)
	if player.Parent then
		Remotes.QueueStatus:FireClient(player, buildStatusForPlayer(player))
	end
end

local function broadcastAllQueueStatus()
	for _, player in Players:GetPlayers() do
		sendQueueStatus(player)
	end
	HubService.broadcastLobby()
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueueList(queues[modeId], player)
	playerQueue[player] = nil
	queueJoinTime[player] = nil
end

local function popPlayersForMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local matchPlayers = {}

	while #matchPlayers < config.maxPlayers and #queue > 0 do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer.Parent then
			playerQueue[nextPlayer] = nil
			queueJoinTime[nextPlayer] = nil
			table.insert(matchPlayers, nextPlayer)
		end
	end

	return matchPlayers
end

local function tryStartMatch(modeId)
	if not matchIdle then
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	gatherTokens[modeId] = (gatherTokens[modeId] or 0) + 1
	local token = gatherTokens[modeId]

	task.delay(MatchmakingConfig.GATHER_DELAY, function()
		if token ~= gatherTokens[modeId] or not matchIdle then
			return
		end

		local queueNow = queues[modeId]
		if #queueNow < config.minPlayers then
			return
		end

		local matchPlayers = popPlayersForMatch(modeId)
		if #matchPlayers < config.minPlayers then
			for _, queuedPlayer in matchPlayers do
				table.insert(queueNow, queuedPlayer)
				playerQueue[queuedPlayer] = modeId
				queueJoinTime[queuedPlayer] = os.clock()
			end
			return
		end

		matchIdle = false
		for _, queuedPlayer in matchPlayers do
			HubService.enterArena(queuedPlayer)
		end

		broadcastAllQueueStatus()
		Bindables.MatchReady:Fire(matchPlayers, modeId)
	end)
end

local function joinQueue(player, modeId)
	if not isValidMode(modeId) or not matchIdle then
		return false
	end

	if playerQueue[player] == modeId then
		sendQueueStatus(player)
		return true
	end

	clearPlayerFromQueues(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	queueJoinTime[player] = os.clock()
	HubService.enterQueue(player, modeId)

	sendQueueStatus(player)
	broadcastAllQueueStatus()
	tryStartMatch(modeId)
	return true
end

local function leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	clearPlayerFromQueues(player)
	gatherTokens[modeId] = (gatherTokens[modeId] or 0) + 1

	HubService.returnPlayerToHub(player)
	broadcastAllQueueStatus()
end

local function getRecommendedModeId()
	local counts = getQueueCounts()
	if counts.ffa >= MatchmakingConfig.MODES.ffa.minPlayers then
		return "ffa"
	end
	if counts.pvp >= MatchmakingConfig.MODES.pvp.minPlayers then
		return "pvp"
	end
	if counts.training > 0 then
		return "training"
	end

	local playerCount = #Players:GetPlayers()
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount >= 2 then
		return "pvp"
	end
	return "training"
end

local function notifyIdle()
	matchIdle = true
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

local function checkQueueTimeouts()
	local now = os.clock()
	for player, joinedAt in queueJoinTime do
		if now - joinedAt >= MatchmakingConfig.QUEUE_TIMEOUT then
			leaveQueue(player)
		end
	end
end

local function start()
	if initialized then
		return
	end
	initialized = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = getRecommendedModeId()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearPlayerFromQueues(player)
		task.defer(broadcastAllQueueStatus)
	end)

	Bindables.EnterArena.Event:Connect(function(player)
		joinQueue(player, getRecommendedModeId())
	end)

	task.spawn(function()
		while true do
			task.wait(10)
			checkQueueTimeouts()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

local MatchmakingService = {
	start = start,
	joinQueue = joinQueue,
	leaveQueue = leaveQueue,
	getRecommendedModeId = getRecommendedModeId,
	getQueueCounts = getQueueCounts,
	getPlayerMode = function(player)
		return playerQueue[player]
	end,
	notifyIdle = notifyIdle,
	buildStatusForPlayer = buildStatusForPlayer,
}

return MatchmakingService
