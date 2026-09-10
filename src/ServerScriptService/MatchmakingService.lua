local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTimers = {}
local arenaBusy = false
local onMatchReady = nil
local onQueueChanged = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
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

	local mode = getMode(modeId)
	if mode and #queue < mode.minPlayers then
		clearFillTimer(modeId)
	end

	if onQueueChanged then
		onQueueChanged()
	end
end

local function buildQueueSnapshot(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	local status = "waiting"
	if arenaBusy then
		status = "pending"
	elseif mode and #queue >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		label = mode and mode.label or modeId,
		count = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		fillTimeout = mode and mode.fillTimeout or 0,
		players = names,
		status = status,
	}
end

function MatchmakingService.getPlayerQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end
	return buildQueueSnapshot(modeId)
end

function MatchmakingService.getAllSnapshots()
	local snapshots = {}
	for modeId in MatchmakingConfig.MODES do
		snapshots[modeId] = buildQueueSnapshot(modeId)
	end
	return snapshots
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if onQueueChanged then
		onQueueChanged()
	end
end

function MatchmakingService.setOnMatchReady(callback)
	onMatchReady = callback
end

function MatchmakingService.setOnQueueChanged(callback)
	onQueueChanged = callback
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return false, "invalid_mode"
	end
	if playerMode[player] == modeId then
		return true
	end

	removeFromQueue(player)

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerMode[player] = modeId

	if mode.fillTimeout > 0 and #queue >= 2 and not fillTimers[modeId] then
		fillTimers[modeId] = task.delay(mode.fillTimeout, function()
			fillTimers[modeId] = nil
			MatchmakingService.tryStartMatch(modeId)
		end)
	end

	if onQueueChanged then
		onQueueChanged()
	end

	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.tryStartMatch(modeId)
	if arenaBusy or not onMatchReady then
		return
	end

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not mode or #queue < mode.minPlayers then
		return
	end

	local matched = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		local queuedPlayer = queue[i]
		if queuedPlayer.Parent then
			table.insert(matched, queuedPlayer)
		end
	end

	if #matched < mode.minPlayers then
		return
	end

	clearFillTimer(modeId)
	queues[modeId] = {}

	for _, matchedPlayer in matched do
		playerMode[matchedPlayer] = nil
	end

	if onQueueChanged then
		onQueueChanged()
	end

	onMatchReady(matched, modeId)
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

return MatchmakingService
