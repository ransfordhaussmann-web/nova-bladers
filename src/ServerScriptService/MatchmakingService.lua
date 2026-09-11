local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTokens = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
	fillTokens[modeId] = 0
end

local function getMode(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	return modeId
end

local function buildQueueSnapshot(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = #queue
	local status = "waiting"

	if arenaBusy and count > 0 then
		status = "pending"
	elseif mode and count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		label = mode and mode.label or modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
	}
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueSnapshot(modeId)
	if not isValidMode(modeId) then
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

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return nil
	end

	fillTokens[modeId] += 1
	return modeId
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		return true, modeId
	end

	removeFromQueue(player)

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	return true, modeId
end

function MatchmakingService.scheduleFillTimer(modeId, callback)
	local mode = getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers or #queue >= mode.maxPlayers then
		return
	end

	fillTokens[modeId] += 1
	local token = fillTokens[modeId]
	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		callback(modeId)
	end)
end

function MatchmakingService.tryLaunch(modeId)
	if arenaBusy then
		return nil
	end

	local mode = getMode(modeId)
	if not mode then
		return nil
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return nil
	end

	local players = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(players, queue[i])
	end

	for _, player in players do
		removeFromQueue(player)
	end

	fillTokens[modeId] += 1
	return players
end

function MatchmakingService.tryLaunchAll()
	if arenaBusy then
		return nil
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		local players = MatchmakingService.tryLaunch(modeId)
		if players then
			return players, modeId
		end
	end

	return nil
end

function MatchmakingService.clearPlayer(player)
	return removeFromQueue(player)
end

return MatchmakingService
