local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local arenaBusy = false
local fillTimers = {}
local callbacks = {}

for _, modeId in MatchmakingConfig.ORDER do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function buildQueuePayload(modeId, player)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local mode = getModeConfig(modeId)
	local status = "waiting"
	if arenaBusy then
		status = "pending"
	end

	return {
		status = status,
		mode = modeId,
		modeLabel = mode.label,
		position = position,
		total = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = arenaBusy,
	}
end

local function notifyPlayer(player, modeId)
	if callbacks.onQueueUpdate and player.Parent then
		callbacks.onQueueUpdate(player, buildQueuePayload(modeId, player))
	end
end

local function notifyQueue(modeId)
	for _, player in queues[modeId] do
		notifyPlayer(player, modeId)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end

	local modeId = entry.mode
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
	clearFillTimer(modeId)
	notifyQueue(modeId)
	return modeId
end

local function canStartMatch(modeId)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	return #queue >= mode.minPlayers and not arenaBusy
end

local function popPlayersForMatch(modeId)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local players = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(players, player)
			playerEntry[player] = nil
		end
	end

	clearFillTimer(modeId)
	notifyQueue(modeId)
	return players
end

local function tryStartMatch(modeId)
	if not canStartMatch(modeId) then
		return false
	end

	local mode = getModeConfig(modeId)
	local queue = queues[modeId]

	if modeId == "ffa" and #queue < mode.maxPlayers then
		if not fillTimers[modeId] then
			fillTimers[modeId] = task.delay(mode.fillTimeout or 12, function()
				fillTimers[modeId] = nil
				if canStartMatch(modeId) then
					MatchmakingService._startMatch(modeId)
				end
			end)
		end
		return false
	end

	return MatchmakingService._startMatch(modeId)
end

function MatchmakingService._startMatch(modeId)
	if not canStartMatch(modeId) then
		return false
	end

	local players = popPlayersForMatch(modeId)
	local mode = getModeConfig(modeId)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return false
	end

	arenaBusy = true
	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, players)
	end
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.isValidMode(modeId) then
		return false
	end
	if playerEntry[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = { mode = modeId }
	notifyPlayer(player, modeId)
	notifyQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId and callbacks.onQueueLeft then
		callbacks.onQueueLeft(player)
	end
	return modeId ~= nil
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerEntry[player]
	return entry and entry.mode
end

function MatchmakingService.isInQueue(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for _, modeId in MatchmakingConfig.ORDER do
		notifyQueue(modeId)
	end
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	for _, modeId in MatchmakingConfig.ORDER do
		notifyQueue(modeId)
		tryStartMatch(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.registerCallbacks(newCallbacks)
	callbacks = newCallbacks
end

return MatchmakingService
