local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local ffaFillStarted = {}
local pendingMatch = nil
local running = false

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
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

	playerMode[player] = nil
	ffaFillStarted[modeId] = nil
end

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if pendingMatch and table.find(pendingMatch.players, player) then
		status = "pending"
	end

	local fillRemaining = nil
	if modeId == "ffa" and ffaFillStarted[modeId] then
		local configFfa = getModeConfig("ffa")
		fillRemaining = math.max(0, configFfa.fillTimeout - (os.clock() - ffaFillStarted[modeId]))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		position = position,
		count = #queue,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		arenaBusy = GameMatchState.isArenaBusy(),
		fillRemaining = fillRemaining,
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates()
	for modeId, queue in queues do
		for _, player in queue do
			sendQueueUpdate(player)
		end
	end
	if pendingMatch then
		for _, player in pendingMatch.players do
			sendQueueUpdate(player)
		end
	end
end

local function canStartMode(modeId)
	local config = getModeConfig(modeId)
	local count = getQueueCount(modeId)
	if count < config.minPlayers then
		return false
	end
	if count >= config.maxPlayers then
		return true
	end
	if modeId == "ffa" and ffaFillStarted[modeId] then
		local elapsed = os.clock() - ffaFillStarted[modeId]
		return elapsed >= config.fillTimeout
	end
	return modeId ~= "ffa" and count >= config.minPlayers
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(taken, player)
			playerMode[player] = nil
		end
	end
	ffaFillStarted[modeId] = nil
	return taken
end

local function tryLaunchMatch(modeId)
	if not canStartMode(modeId) then
		return false
	end

	local config = getModeConfig(modeId)
	local players = takePlayersFromQueue(modeId, config.maxPlayers)
	if #players < config.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerMode[player] = modeId
		end
		return false
	end

	if GameMatchState.isArenaBusy() then
		if pendingMatch then
			for i = #players, 1, -1 do
				table.insert(queues[modeId], 1, players[i])
				playerMode[players[i]] = modeId
			end
			return false
		end

		pendingMatch = { modeId = modeId, players = players }
		for _, player in players do
			playerMode[player] = modeId
		end
		broadcastQueueUpdates()
		return true
	end

	GameMatchState.setArenaBusy(true)
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = players,
	})
	return true
end

local function checkQueues()
	for modeId in MatchmakingConfig.MODES do
		local config = getModeConfig(modeId)
		local count = getQueueCount(modeId)

		if modeId == "ffa" and count >= config.minPlayers and not ffaFillStarted[modeId] then
			ffaFillStarted[modeId] = os.clock()
		end

		if canStartMode(modeId) then
			tryLaunchMatch(modeId)
			break
		end
	end
end

local function launchPendingMatch()
	if not pendingMatch or GameMatchState.isArenaBusy() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil

	for _, player in match.players do
		playerMode[player] = nil
	end

	GameMatchState.setArenaBusy(true)
	Bindables.MatchReady:Fire({
		mode = match.modeId,
		players = match.players,
	})
	broadcastQueueUpdates()
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) or not player.Parent then
		return false
	end
	if playerMode[player] then
		return false
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	local config = getModeConfig(modeId)
	if modeId == "ffa" and getQueueCount(modeId) >= config.minPlayers then
		ffaFillStarted[modeId] = os.clock()
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates()
	checkQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return false
	end

	removeFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdates()
	return true
end

function MatchmakingService.getRecommendedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onArenaFree()
	launchPendingMatch()
	checkQueues()
	broadcastQueueUpdates()
end

function MatchmakingService.onPlayerRemoving(player)
	if pendingMatch then
		local idx = table.find(pendingMatch.players, player)
		if idx then
			table.remove(pendingMatch.players, idx)
			if #pendingMatch.players < getModeConfig(pendingMatch.modeId).minPlayers then
				for _, p in pendingMatch.players do
					table.insert(queues[pendingMatch.modeId], p)
					playerMode[p] = pendingMatch.modeId
				end
				pendingMatch = nil
			end
		end
	end
	removeFromQueue(player)
end

function MatchmakingService.isInQueue(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.start()
	if running then
		return
	end
	running = true

	task.spawn(function()
		while running do
			checkQueues()
			broadcastQueueUpdates()
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		end
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
