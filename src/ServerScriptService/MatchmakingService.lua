local MatchmakingService = {}

local config
local queues = {}
local playerEntry = {}
local arenaBusy = false
local callbacks = {}

local function getMode(modeId)
	return config.MODES[modeId]
end

local function getQueueNames(modeId)
	local names = {}
	for _, player in queues[modeId].list do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end
	return names
end

local function buildPayload(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = getMode(entry.modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = queues[entry.modeId]
	local count = #queue.list
	local message

	if entry.status == "pending" then
		message = "Arena belegt — warte auf freien Slot..."
	elseif count >= mode.maxPlayers then
		message = "Match startet gleich..."
	elseif count >= mode.minPlayers and mode.fillTimeout > 0 then
		message = string.format("Warte auf Spieler (%d/%d)...", count, mode.maxPlayers)
	elseif count < mode.minPlayers then
		message = string.format("Warte auf Spieler (%d/%d)", count, mode.minPlayers)
	else
		message = "Match startet gleich..."
	end

	return {
		inQueue = true,
		mode = entry.modeId,
		modeLabel = mode.label,
		status = entry.status,
		queueSize = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		players = getQueueNames(entry.modeId),
		message = message,
	}
end

local function broadcastQueueUpdates()
	for player in pairs(playerEntry) do
		if player.Parent and callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(player, buildPayload(player))
		end
	end
end

local function removeFromList(modeId, player)
	local list = queues[modeId].list
	for index, queuedPlayer in ipairs(list) do
		if queuedPlayer == player then
			table.remove(list, index)
			return
		end
	end
end

local function cancelFillTimer(modeId)
	queues[modeId].fillToken += 1
end

local function markQueuePending(modeId)
	for _, player in queues[modeId].list do
		local entry = playerEntry[player]
		if entry then
			entry.status = "pending"
		end
	end
	broadcastQueueUpdates()
end

local function takePlayers(modeId)
	local mode = getMode(modeId)
	local list = queues[modeId].list
	local takeCount = math.min(#list, mode.maxPlayers)
	local players = {}

	for index = 1, takeCount do
		table.insert(players, list[index])
	end

	for index = 1, takeCount do
		table.remove(list, 1)
	end

	cancelFillTimer(modeId)

	for _, player in players do
		playerEntry[player] = nil
	end

	return players
end

function MatchmakingService.startMatch(modeId)
	if arenaBusy then
		markQueuePending(modeId)
		return
	end

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if #queue.list < mode.minPlayers then
		return
	end

	local players = takePlayers(modeId)
	if #players < mode.minPlayers then
		return
	end

	arenaBusy = true
	broadcastQueueUpdates()

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 then
		MatchmakingService.startMatch(modeId)
		return
	end

	local queue = queues[modeId]
	queue.fillToken += 1
	local token = queue.fillToken

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken or arenaBusy then
			return
		end
		if #queue.list >= mode.minPlayers then
			MatchmakingService.startMatch(modeId)
		end
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getMode(modeId)
	local count = #queues[modeId].list

	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		MatchmakingService.startMatch(modeId)
		return
	end

	if mode.fillTimeout <= 0 then
		MatchmakingService.startMatch(modeId)
		return
	end

	scheduleFillTimer(modeId)
end

function MatchmakingService.init(matchmakingConfig, serviceCallbacks)
	config = matchmakingConfig
	callbacks = serviceCallbacks

	for modeId in config.MODES do
		queues[modeId] = {
			list = {},
			fillToken = 0,
		}
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		for _, entry in playerEntry do
			entry.status = "waiting"
		end
		broadcastQueueUpdates()
		for modeId in config.MODES do
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	removeFromList(entry.modeId, player)
	cancelFillTimer(entry.modeId)
	playerEntry[player] = nil

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { inQueue = false })
	end
	broadcastQueueUpdates()

	MatchmakingService.tryStartMatch(entry.modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		modeId = config.DEFAULT_MODE
	end

	MatchmakingService.leaveQueue(player)

	local status = if arenaBusy then "pending" else "waiting"
	playerEntry[player] = {
		modeId = modeId,
		status = status,
	}
	table.insert(queues[modeId].list, player)

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, buildPayload(player))
	end
	broadcastQueueUpdates()

	if not arenaBusy then
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.removePlayer(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.getQueueStatus(player)
	return buildPayload(player)
end

return MatchmakingService
