local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local fillTimers = {}
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countActive(entries)
	local n = 0
	for _, entry in entries do
		if entry.player.Parent then
			n += 1
		end
	end
	return n
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local cleaned = {}
	for _, entry in queue do
		if entry.player.Parent then
			table.insert(cleaned, entry)
		else
			playerEntry[entry.player] = nil
		end
	end
	queues[modeId] = cleaned
end

local function buildQueuePayload(player, modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return nil
	end

	pruneQueue(modeId)
	local queue = queues[modeId]
	local count = countActive(queue)
	local pendingArena = MatchStateService.isArenaBusy()
	local fillEndsAt = fillTimers[modeId]

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queueCount = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		inQueue = playerEntry[player] ~= nil,
		pendingArena = pendingArena,
		fillEndsAt = fillEndsAt,
	}
end

local function notifyPlayer(player)
	local entry = playerEntry[player]
	if not entry or not callbacks.onQueueUpdate then
		return
	end
	callbacks.onQueueUpdate(player, buildQueuePayload(player, entry.modeId))
end

local function notifyQueue(modeId)
	pruneQueue(modeId)
	for _, entry in queues[modeId] do
		notifyPlayer(entry.player)
	end
end

local function cancelFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function popPlayers(modeId, count)
	pruneQueue(modeId)
	local picked = {}
	local remaining = {}

	for _, entry in queues[modeId] do
		if #picked < count then
			table.insert(picked, entry.player)
			playerEntry[entry.player] = nil
		else
			table.insert(remaining, entry)
		end
	end

	queues[modeId] = remaining
	cancelFillTimer(modeId)
	return picked
end

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end

	notifyQueue(modeId)
	for _, modeKey in { "training", "pvp", "ffa" } do
		if modeKey ~= modeId then
			notifyQueue(modeKey)
		end
	end
end

local function maybeStartFillTimer(modeId)
	local mode = getModeConfig(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end
	if fillTimers[modeId] then
		return
	end

	local endsAt = os.clock() + mode.fillTimeout
	fillTimers[modeId] = endsAt

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= endsAt then
			return
		end
		if MatchStateService.isArenaBusy() then
			return
		end

		pruneQueue(modeId)
		local count = countActive(queues[modeId])
		if count >= mode.minPlayers then
			local take = math.min(count, mode.maxPlayers)
			local players = popPlayers(modeId, take)
			startMatch(modeId, players)
		else
			cancelFillTimer(modeId)
			notifyQueue(modeId)
		end
	end)

	notifyQueue(modeId)
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		notifyQueue(modeId)
		return
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local count = countActive(queues[modeId])

	if count >= mode.maxPlayers then
		local players = popPlayers(modeId, mode.maxPlayers)
		startMatch(modeId, players)
		return
	end

	if modeId == "ffa" then
		if count >= mode.minPlayers then
			maybeStartFillTimer(modeId)
		end
		return
	end

	if count >= mode.minPlayers then
		local players = popPlayers(modeId, mode.minPlayers)
		startMatch(modeId, players)
	end
end

function MatchmakingService.onArenaFreed()
	for _, modeId in { "training", "pvp", "ffa" } do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return false
	end

	local modeId = entry.modeId
	playerEntry[player] = nil

	local remaining = {}
	for _, queued in queues[modeId] do
		if queued.player ~= player then
			table.insert(remaining, queued)
		end
	end
	queues[modeId] = remaining

	if countActive(queues[modeId]) < getModeConfig(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	notifyQueue(modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return false
	end

	MatchmakingService.leaveQueue(player)

	playerEntry[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}
	table.insert(queues[modeId], {
		player = player,
		joinedAt = os.clock(),
	})

	notifyPlayer(player)
	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId or nil
end

function MatchmakingService.isInQueue(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.clearPlayer(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.registerHandlers(newCallbacks)
	callbacks = newCallbacks or {}
end

return MatchmakingService
