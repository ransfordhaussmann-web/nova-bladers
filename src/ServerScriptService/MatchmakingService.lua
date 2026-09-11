local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerEntries = {}
local arenaBusy = false
local onMatchReady = nil

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillToken = 0,
		}
	end
	return queues[modeId]
end

local function removeFromQueueList(queue, player)
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			return true
		end
	end
	return false
end

local function clearFillTimer(queue)
	queue.fillToken += 1
end

local function buildQueuePayload(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local entry = playerEntries[player]
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		status = entry and entry.status or MatchmakingConfig.QUEUE_STATUS.Queued,
		position = 0,
		queued = #queue.players,
		required = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		arenaBusy = arenaBusy,
	}
end

function MatchmakingService.setBroadcast(fn)
	MatchmakingService._broadcast = fn
end

function MatchmakingService.setMatchReadyCallback(fn)
	onMatchReady = fn
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	MatchmakingService.broadcastAll()
	if not busy then
		MatchmakingService.tryStartMatches()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerEntries[player]
	return entry and entry.modeId
end

function MatchmakingService.broadcastPlayer(player)
	if not MatchmakingService._broadcast then
		return
	end
	local entry = playerEntries[player]
	if not entry then
		MatchmakingService._broadcast(player, nil)
		return
	end
	MatchmakingService._broadcast(player, buildQueuePayload(entry.modeId, player))
end

function MatchmakingService.broadcastAll()
	for player in playerEntries do
		if player.Parent then
			MatchmakingService.broadcastPlayer(player)
		end
	end
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntries[player]
	if not entry then
		return false
	end

	local queue = getQueue(entry.modeId)
	removeFromQueueList(queue, player)
	playerEntries[player] = nil

	if #queue.players == 0 then
		clearFillTimer(queue)
	end

	MatchmakingService.broadcastPlayer(player)
	return true
end

local function canStartMode(modeId, count)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end
	return count >= mode.minPlayers and count <= mode.maxPlayers
end

local function markPlayersStarting(modeId, playerList)
	for _, player in playerList do
		local entry = playerEntries[player]
		if entry then
			entry.status = MatchmakingConfig.QUEUE_STATUS.Starting
		end
		MatchmakingService.broadcastPlayer(player)
	end
end

local function consumePlayers(modeId, count)
	local queue = getQueue(modeId)
	local selected = {}
	for index = 1, math.min(count, #queue.players) do
		local player = queue.players[index]
		table.insert(selected, player)
	end

	for _, player in selected do
		removeFromQueueList(queue, player)
		playerEntries[player] = nil
	end

	if #queue.players == 0 then
		clearFillTimer(queue)
	end

	return selected
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	local count = #queue.players
	if count < mode.minPlayers then
		return false
	end

	if arenaBusy then
		for _, player in queue.players do
			local entry = playerEntries[player]
			if entry then
				entry.status = MatchmakingConfig.QUEUE_STATUS.Pending
			end
		end
		MatchmakingService.broadcastAll()
		return false
	end

	local startCount = math.min(count, mode.maxPlayers)
	if not canStartMode(modeId, startCount) then
		return false
	end

	local players = consumePlayers(modeId, startCount)
	if #players == 0 then
		return false
	end

	markPlayersStarting(modeId, players)
	arenaBusy = true

	if onMatchReady then
		onMatchReady({
			mode = modeId,
			players = players,
		})
	end

	MatchmakingService.broadcastAll()
	return true
end

function MatchmakingService.tryStartMatches()
	for modeId in MatchmakingConfig.MODES do
		MatchmakingService.tryStartMatch(modeId)
	end
end

local function scheduleFillTimeout(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	local queue = getQueue(modeId)
	queue.fillToken += 1
	local token = queue.fillToken

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		if #queue.players >= mode.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerEntries[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue.players >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue.players, player)
	playerEntries[player] = {
		modeId = modeId,
		status = arenaBusy
			and MatchmakingConfig.QUEUE_STATUS.Pending
			or MatchmakingConfig.QUEUE_STATUS.Queued,
	}

	MatchmakingService.broadcastPlayer(player)

	if mode.fillTimeout > 0 and #queue.players == 1 then
		scheduleFillTimeout(modeId)
	end

	if canStartMode(modeId, #queue.players) and mode.fillTimeout <= 0 then
		MatchmakingService.tryStartMatch(modeId)
	elseif canStartMode(modeId, #queue.players) and #queue.players >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
