local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local arenaBusy = false
local remotes = nil
local onMatchReady = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function pruneQueue(modeId)
	local queue = ensureQueue(modeId)
	local pruned = {}
	for _, player in queue do
		if player.Parent then
			table.insert(pruned, player)
		else
			playerQueue[player] = nil
		end
	end
	queues[modeId] = pruned
end

local function buildQueuePayload(player, modeId)
	local config = getModeConfig(modeId)
	if not config then
		return nil
	end

	pruneQueue(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue
	local needed = math.max(0, config.minPlayers - count)
	local status = "waiting"

	if arenaBusy then
		status = "pending"
	elseif modeId == "ffa" and count >= config.minPlayers and fillTimers[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		label = config.label,
		count = count,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		needed = needed,
		status = status,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	if not remotes then
		return
	end

	pruneQueue(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
	end
end

local function cancelFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function popPlayersForMatch(modeId)
	pruneQueue(modeId)
	local config = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local take = math.min(#queue, config.maxPlayers)
	local players = {}

	for i = 1, take do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(players, player)
		end
	end

	cancelFillTimer(modeId)
	broadcastQueue(modeId)
	return players
end

local function canStartMode(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return false
	end

	pruneQueue(modeId)
	local count = #ensureQueue(modeId)
	return count >= config.minPlayers
end

local function tryStartMatch(modeId)
	if arenaBusy or not canStartMode(modeId) then
		broadcastQueue(modeId)
		return
	end

	local config = getModeConfig(modeId)
	local players = popPlayersForMatch(modeId)
	if #players < config.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	arenaBusy = true
	broadcastAllQueues()

	if onMatchReady then
		onMatchReady(players, modeId)
	end
end

local function scheduleFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config or config.fillTimeout <= 0 then
		return
	end

	cancelFillTimer(modeId)
	fillTimers[modeId] = task.delay(config.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function evaluateMode(modeId)
	if not canStartMode(modeId) then
		broadcastQueue(modeId)
		return
	end

	local config = getModeConfig(modeId)
	local count = #ensureQueue(modeId)

	if config.maxPlayers > 0 and count >= config.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if config.fillTimeout > 0 then
		if count >= config.minPlayers and not fillTimers[modeId] then
			scheduleFillTimer(modeId)
		end
		broadcastQueue(modeId)
		return
	end

	tryStartMatch(modeId)
end

function MatchmakingService.init(remoteEvents, matchReadyCallback)
	remotes = remoteEvents
	onMatchReady = matchReadyCallback

	for modeId in MatchmakingConfig.MODES do
		ensureQueue(modeId)
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = ensureQueue(modeId)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	if #queue < getModeConfig(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	local config = getModeConfig(modeId)
	if not config then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(ensureQueue(modeId), player)
	playerQueue[player] = modeId
	evaluateMode(modeId)
	return true
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	broadcastAllQueues()

	for modeId in MatchmakingConfig.MODES do
		evaluateMode(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
