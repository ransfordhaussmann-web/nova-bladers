local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local arenaBusy = false
local pendingLaunch = nil
local callbacks = {}

local function copyQueuePlayers(modeId, count)
	local queue = queues[modeId]
	local players = {}
	local take = math.min(count or #queue, #queue)
	for i = 1, take do
		table.insert(players, queue[i])
	end
	return players
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, p in ipairs(queue) do
		if p == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	return {
		inQueue = true,
		modeId = modeId,
		label = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = arenaBusy,
	}
end

local function broadcastQueueUpdates()
	if not callbacks.onQueueUpdate then
		return
	end

	local seen = {}
	for _, queue in pairs(queues) do
		for _, player in ipairs(queue) do
			if player.Parent and not seen[player] then
				seen[player] = true
				callbacks.onQueueUpdate(player, buildQueuePayload(player))
			end
		end
	end
end

local function clearPendingIfNeeded(modeId)
	if pendingLaunch and pendingLaunch.modeId == modeId then
		pendingLaunch = nil
	end
end

local function launchMatch(modeId, players)
	arenaBusy = true

	for _, player in ipairs(players) do
		removePlayerFromQueue(player)
	end

	clearPendingIfNeeded(modeId)
	broadcastQueueUpdates()

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

local function canLaunch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	return #queue >= mode.minPlayers
end

local function tryLaunchMatch(modeId)
	if not canLaunch(modeId) then
		clearPendingIfNeeded(modeId)
		broadcastQueueUpdates()
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local players = copyQueuePlayers(modeId, mode.maxPlayers)

	if arenaBusy then
		pendingLaunch = {
			modeId = modeId,
			players = players,
		}
		broadcastQueueUpdates()
		return
	end

	launchMatch(modeId, players)
end

local function scheduleFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if mode.fillTimeout <= 0 then
		tryLaunchMatch(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		tryLaunchMatch(modeId)
	end)
end

local function onQueueChanged(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]

	if #queue < mode.minPlayers then
		if fillTimers[modeId] then
			task.cancel(fillTimers[modeId])
			fillTimers[modeId] = nil
		end
		clearPendingIfNeeded(modeId)
		broadcastQueueUpdates()
		return
	end

	if #queue >= mode.maxPlayers then
		if fillTimers[modeId] then
			task.cancel(fillTimers[modeId])
			fillTimers[modeId] = nil
		end
		tryLaunchMatch(modeId)
		return
	end

	scheduleFillTimer(modeId)
	broadcastQueueUpdates()
end

function MatchmakingService.setCallbacks(newCallbacks)
	callbacks = newCallbacks
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy

	if not arenaBusy and pendingLaunch then
		local launch = pendingLaunch
		pendingLaunch = nil

		local stillQueued = {}
		for _, player in ipairs(launch.players) do
			if player.Parent and playerQueue[player] == launch.modeId then
				table.insert(stillQueued, player)
			end
		end

		if #stillQueued >= MatchmakingConfig.getMode(launch.modeId).minPlayers then
			launchMatch(launch.modeId, stillQueued)
			return
		end
	end

	broadcastQueueUpdates()
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		return true
	end

	removePlayerFromQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player]
	removePlayerFromQueue(player)
	onQueueChanged(modeId)

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { inQueue = false })
	end

	return true
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.onPlayerRemoving(player)
	removePlayerFromQueue(player)
	for modeId in pairs(queues) do
		onQueueChanged(modeId)
	end
end

return MatchmakingService
