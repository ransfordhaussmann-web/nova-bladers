local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local arenaBusy = false
local fillTokens = {}
local callbacks = {}

local function getQueueList(modeId)
	return queues[modeId] or queues.training
end

local function countValidPlayers(queue)
	local count = 0
	for _, player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function compactQueue(modeId)
	local queue = getQueueList(modeId)
	local compacted = {}
	for _, player in queue do
		if player.Parent then
			table.insert(compacted, player)
		else
			playerQueue[player] = nil
		end
	end
	queues[modeId] = compacted
	return compacted
end

local function buildUpdate(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = compactQueue(modeId)
	local count = #queue
	local needed = mode.minPlayers

	local status = MatchmakingConfig.STATUS.Queued
	if arenaBusy then
		status = MatchmakingConfig.STATUS.Pending
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		needed = needed,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	if not callbacks.onQueueUpdate then
		return
	end

	local queue = compactQueue(modeId)
	for _, player in queue do
		callbacks.onQueueUpdate(player, buildUpdate(player, modeId))
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function popPlayers(modeId, amount)
	local queue = compactQueue(modeId)
	local players = {}
	local take = math.min(amount, #queue)

	for i = 1, take do
		local player = queue[i]
		table.insert(players, player)
		playerQueue[player] = nil
	end

	local remaining = {}
	for i = take + 1, #queue do
		table.insert(remaining, queue[i])
	end
	queues[modeId] = remaining

	return players
end

local function notifyStarting(players, modeId)
	if not callbacks.onQueueUpdate then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	for _, player in players do
		if player.Parent then
			callbacks.onQueueUpdate(player, {
				modeId = modeId,
				modeLabel = mode.label,
				count = #players,
				needed = mode.minPlayers,
				maxPlayers = mode.maxPlayers,
				status = MatchmakingConfig.STATUS.Starting,
				inQueue = false,
			})
		end
	end
end

function MatchmakingService.configure(newCallbacks)
	callbacks = newCallbacks
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		MatchmakingService.processAllQueues()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getQueueState(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end
	return buildUpdate(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	playerQueue[player] = nil
	compactQueue(modeId)

	if modeId == "ffa" then
		local queue = getQueueList(modeId)
		if #queue < MatchmakingConfig.MODES.ffa.minPlayers then
			clearFillTimer(modeId)
		end
	end

	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.getMode(modeId) then
		return false, "Ungültiger Modus"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(getQueueList(modeId), player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(modeId)
	MatchmakingService.tryStartMatch(modeId)

	return true
end

function MatchmakingService.tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = compactQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			clearFillTimer(modeId)
			MatchmakingService.startMatch(modeId, mode.maxPlayers)
		elseif count >= mode.minPlayers then
			MatchmakingService.scheduleFillTimer(modeId)
		end
	else
		MatchmakingService.startMatch(modeId, mode.minPlayers)
	end
end

function MatchmakingService.scheduleFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode.fillTimeout then
		MatchmakingService.startMatch(modeId, mode.minPlayers)
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] or arenaBusy then
			return
		end

		local queue = compactQueue(modeId)
		if #queue >= mode.minPlayers then
			MatchmakingService.startMatch(modeId, #queue)
		end
	end)
end

function MatchmakingService.startMatch(modeId, playerCount)
	if arenaBusy then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = compactQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	clearFillTimer(modeId)
	arenaBusy = true

	local take = math.min(playerCount or mode.minPlayers, mode.maxPlayers, #queue)
	local players = popPlayers(modeId, take)

	notifyStarting(players, modeId)
	broadcastQueueUpdate(modeId)

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

function MatchmakingService.processAllQueues()
	for modeId in MatchmakingConfig.MODES do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
