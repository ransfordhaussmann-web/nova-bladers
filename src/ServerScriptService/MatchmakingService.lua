local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local remotes
local bindables

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTimers = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function buildUpdatePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local config = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players
	local status = "waiting"

	if arenaBusy then
		status = "pending"
	end

	local fillTimeLeft
	local timer = fillTimers[modeId]
	if timer and not timer.cancelled then
		fillTimeLeft = math.max(0, math.ceil(timer.deadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		playersInQueue = count,
		playersNeeded = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		fillTimeLeft = fillTimeLeft,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue.players do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueueUpdate(modeId)
	end
end

local function takePlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function canStartNow(modeId)
	local config = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players

	if count < config.minPlayers then
		return false
	end

	if count >= config.maxPlayers then
		return true
	end

	if modeId == "ffa" then
		local timer = fillTimers[modeId]
		if timer and not timer.cancelled and os.clock() >= timer.deadline then
			return true
		end
		return false
	end

	return count >= config.minPlayers
end

local function startFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = { cancelled = false, deadline = os.clock() + config.fillTimeout }
	fillTimers[modeId] = token

	task.delay(config.fillTimeout, function()
		if token.cancelled or fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.init(remoteFolder, bindableFolder)
	remotes = remoteFolder
	bindables = bindableFolder

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

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return false, "invalid_mode"
	end

	if arenaBusy and playerQueue[player] == modeId then
		broadcastQueueUpdate(modeId)
		return true
	end

	removeFromQueue(player)
	playerQueue[player] = modeId

	local queue = ensureQueue(modeId)
	table.insert(queue.players, player)

	if modeId == "ffa" and #queue.players >= getModeConfig(modeId).minPlayers then
		startFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	removeFromQueue(player)
	remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.tryStartMatch(modeId)
	if arenaBusy then
		broadcastQueueUpdate(modeId)
		return
	end

	if not canStartNow(modeId) then
		broadcastQueueUpdate(modeId)
		return
	end

	local config = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local playerCount = math.min(#queue.players, config.maxPlayers)
	local players = takePlayers(modeId, playerCount)

	if #players < config.minPlayers then
		for _, player in players do
			table.insert(queue.players, player)
			playerQueue[player] = modeId
		end
		return
	end

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end

	arenaBusy = true
	broadcastAllQueues()
	bindables.MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

function MatchmakingService.onMatchStarted()
	arenaBusy = true
	broadcastAllQueues()
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false

	for modeId in MatchmakingConfig.MODES do
		local config = getModeConfig(modeId)
		local queue = ensureQueue(modeId)
		if modeId == "ffa" and #queue.players >= config.minPlayers then
			startFillTimer(modeId)
		end
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

return MatchmakingService
