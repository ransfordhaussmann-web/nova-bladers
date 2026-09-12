local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTimers = {}
local onQueueUpdate = nil
local onMatchReady = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(player, modeId, status)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = status or "waiting",
		fillTimeout = mode.fillTimeout,
	}
end

local function notifyQueue(modeId)
	if not onQueueUpdate then
		return
	end

	local queue = queues[modeId]
	for _, player in queue do
		if player.Parent then
			local entry = playerQueue[player]
			onQueueUpdate(player, buildQueuePayload(player, modeId, entry and entry.status or "waiting"))
		end
	end
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return false
	end

	if arenaBusy then
		for _, player in queue do
			if playerQueue[player] then
				playerQueue[player].status = "pending"
			end
		end
		notifyQueue(modeId)
		return false
	end

	local playerList = {}
	local takeCount = math.min(#queue, mode.maxPlayers)
	for i = 1, takeCount do
		table.insert(playerList, queue[1])
		removeFromQueue(queue[1])
	end

	arenaBusy = true

	if onMatchReady then
		onMatchReady(playerList, modeId)
	end

	notifyQueue(modeId)
	return true
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		local queue = queues[modeId]
		if #queue >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.setCallbacks(callbacks)
	onQueueUpdate = callbacks.onQueueUpdate
	onMatchReady = callbacks.onMatchReady
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = {
		modeId = modeId,
		status = "waiting",
	}

	notifyQueue(modeId)

	local mode = getMode(modeId)
	local queue = queues[modeId]

	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers and mode.fillTimeout <= 0 then
		tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers and mode.fillTimeout > 0 then
		scheduleFillTimer(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if #queue >= mode.minPlayers and mode.fillTimeout > 0 and not fillTimers[modeId] then
		scheduleFillTimer(modeId)
	end

	notifyQueue(modeId)
	return true
end

function MatchmakingService.getQueueStatus(player)
	local entry = playerQueue[player]
	if not entry then
		return nil
	end
	return buildQueuePayload(player, entry.modeId, entry.status)
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false

	for modeId in MatchmakingConfig.MODES do
		local queue = queues[modeId]
		if #queue > 0 then
			local mode = getMode(modeId)
			if #queue >= mode.minPlayers then
				tryStartMatch(modeId)
			end
		end
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

return MatchmakingService
