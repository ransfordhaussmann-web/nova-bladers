local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local callbacks = {
	isArenaBusy = function()
		return false
	end,
	onMatchReady = function() end,
	onQueueUpdate = function() end,
}

for _, modeId in MatchmakingConfig.ORDER do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isPlayerValid(player)
	return player and player.Parent
end

local function removeFromQueueList(modeId, player)
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function buildStatus(player, modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = #queue
	local needed = mode.minPlayers
	local pending = callbacks.isArenaBusy()

	local message
	if pending then
		message = string.format("Arena belegt — %s (%d/%d)", mode.label, count, needed)
	elseif count < needed then
		message = string.format("Warte auf Spieler… (%d/%d)", count, needed)
	elseif modeId == "ffa" and count < mode.maxPlayers then
		message = string.format("FFA startet bald… (%d/%d)", count, mode.maxPlayers)
	else
		message = string.format("Match startet… (%d/%d)", count, needed)
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queued = count,
		needed = needed,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		message = message,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, queuedPlayer in queue do
		if isPlayerValid(queuedPlayer) then
			callbacks.onQueueUpdate(queuedPlayer, buildStatus(queuedPlayer, modeId))
		end
	end
end

local function clearPlayerQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueueList(modeId, player)
	playerQueue[player] = nil

	if modeId == "ffa" then
		local mode = getMode(modeId)
		if #queues[modeId] < mode.minPlayers then
			cancelFillTimer(modeId)
		end
	end

	broadcastQueueUpdate(modeId)
end

local function canStartMode(modeId)
	local mode = getMode(modeId)
	local count = #queues[modeId]
	if count < mode.minPlayers or count > mode.maxPlayers then
		return false
	end
	if callbacks.isArenaBusy() then
		return false
	end
	return true
end

local function popPlayers(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local players = {}

	for index = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[index]
		if isPlayerValid(player) then
			table.insert(players, player)
		end
	end

	for _, player in players do
		removeFromQueueList(modeId, player)
		playerQueue[player] = nil
		callbacks.onQueueUpdate(player, { inQueue = false })
	end

	cancelFillTimer(modeId)
	return players
end

local function tryStartMode(modeId)
	if not canStartMode(modeId) then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = getMode(modeId)
	local count = #queues[modeId]

	if modeId == "ffa" and count < mode.maxPlayers and fillTimers[modeId] then
		broadcastQueueUpdate(modeId)
		return
	end

	local players = popPlayers(modeId)
	if #players == 0 then
		return
	end

	callbacks.onMatchReady(players, modeId)
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMode(modeId)
	end)
end

local function tryStartAll()
	for _, modeId in MatchmakingConfig.ORDER do
		tryStartMode(modeId)
	end
end

function MatchmakingService.configure(newCallbacks)
	for key, value in newCallbacks do
		callbacks[key] = value
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isPlayerValid(player) then
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	if playerQueue[player] == modeId then
		callbacks.onQueueUpdate(player, buildStatus(player, modeId))
		return
	end

	clearPlayerQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if modeId == "ffa" and #queues[modeId] >= mode.minPlayers then
		scheduleFillTimer(modeId)
	end

	if modeId ~= "ffa" and #queues[modeId] >= mode.maxPlayers then
		tryStartMode(modeId)
	else
		tryStartMode(modeId)
	end

	broadcastQueueUpdate(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		callbacks.onQueueUpdate(player, { inQueue = false })
		return
	end
	clearPlayerQueue(player)
	callbacks.onQueueUpdate(player, { inQueue = false })
end

function MatchmakingService.onPlayerRemoving(player)
	clearPlayerQueue(player)
end

function MatchmakingService.onArenaFreed()
	tryStartAll()
end

function MatchmakingService.getQueueCounts()
	local counts = {}
	for modeId, queue in queues do
		counts[modeId] = #queue
	end
	return counts
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

return MatchmakingService
