local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local fillTimers = {}
local onMatchReady = nil
local onQueueUpdate = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId, status)
	local mode = getModeConfig(modeId)
	if not mode then
		return nil
	end

	local list = queues[modeId] or {}
	return {
		inQueue = true,
		mode = modeId,
		modeLabel = mode.label,
		players = #list,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		statusText = MatchmakingService.getStatusText(modeId, status),
	}
end

function MatchmakingService.getStatusText(modeId, status)
	local mode = getModeConfig(modeId)
	if not mode then
		return ""
	end

	local count = #(queues[modeId] or {})
	if status == "pending" then
		return "Arena belegt — Match startet gleich..."
	elseif status == "starting" then
		return "Match startet..."
	elseif modeId == "training" then
		return "Suche Trainingsplatz..."
	elseif modeId == "pvp" then
		return string.format("Warte auf Gegner (%d/%d)", count, mode.minPlayers)
	elseif modeId == "ffa" then
		if count < mode.minPlayers then
			return string.format("Warte auf Spieler (%d/%d)", count, mode.minPlayers)
		end
		return string.format("Lobby füllt sich (%d/%d)", count, mode.maxPlayers)
	end
	return "In Warteschlange..."
end

local function broadcastQueueUpdate(modeId, status)
	if not onQueueUpdate then
		return
	end

	local payload = buildQueuePayload(modeId, status)
	if not payload then
		return
	end

	for _, player in queues[modeId] or {} do
		onQueueUpdate(player, payload)
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local list = queues[modeId]
	if list then
		for i, queuedPlayer in list do
			if queuedPlayer == player then
				table.remove(list, i)
				break
			end
		end
	end

	playerQueue[player] = nil
	onQueueUpdate(player, { inQueue = false })

	local mode = getModeConfig(modeId)
	if mode and #(queues[modeId] or {}) < mode.minPlayers then
		clearFillTimer(modeId)
		if pendingMatch and pendingMatch.modeId == modeId then
			pendingMatch = nil
		end
	end

	broadcastQueueUpdate(modeId, pendingMatch and pendingMatch.modeId == modeId and "pending" or "waiting")
end

local function canStartMode(modeId)
	local mode = getModeConfig(modeId)
	local list = queues[modeId] or {}
	if not mode or #list < mode.minPlayers then
		return false
	end
	if modeId == "ffa" and #list < mode.maxPlayers and fillTimers[modeId] then
		return false
	end
	return true
end

local function takePlayersForMatch(modeId)
	local mode = getModeConfig(modeId)
	local list = queues[modeId] or {}
	local count = math.min(#list, mode.maxPlayers)
	local players = {}

	for i = 1, count do
		local player = list[i]
		table.insert(players, player)
		playerQueue[player] = nil
	end

	queues[modeId] = {}
	clearFillTimer(modeId)
	return players
end

local function tryStartMatch(modeId, forcePending)
	if not canStartMode(modeId) then
		return
	end

	if pendingMatch then
		return
	end

	local status = MatchStateService.isArenaBusy() or forcePending == true
	if status then
		pendingMatch = {
			modeId = modeId,
			createdAt = os.clock(),
		}
		broadcastQueueUpdate(modeId, "pending")
		return
	end

	local players = takePlayersForMatch(modeId)
	if #players == 0 then
		return
	end

	for _, player in players do
		onQueueUpdate(player, {
			inQueue = true,
			mode = modeId,
			modeLabel = getModeConfig(modeId).label,
			players = #players,
			needed = getModeConfig(modeId).minPlayers,
			maxPlayers = getModeConfig(modeId).maxPlayers,
			status = "starting",
			statusText = "Match startet...",
		})
	end

	if onMatchReady then
		onMatchReady({
			mode = modeId,
			players = players,
		})
	end
end

local function maybeStartFillTimer(modeId)
	local mode = getModeConfig(modeId)
	local list = queues[modeId] or {}
	if modeId ~= "ffa" or #list < mode.minPlayers or fillTimers[modeId] then
		return
	end

	local startedAt = os.clock()
	fillTimers[modeId] = startedAt
	broadcastQueueUpdate(modeId, "waiting")

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= startedAt then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

function MatchmakingService.registerHandlers(handlers)
	onMatchReady = handlers.onMatchReady
	onQueueUpdate = handlers.onQueueUpdate
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removePlayerFromQueue(player)
	end

	queues[modeId] = queues[modeId] or {}
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(modeId, "waiting")

	local mode = getModeConfig(modeId)
	if modeId == "training" or modeId == "pvp" then
		tryStartMatch(modeId)
	else
		maybeStartFillTimer(modeId)
		if #(queues[modeId] or {}) >= mode.maxPlayers then
			clearFillTimer(modeId)
			tryStartMatch(modeId)
		end
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removePlayerFromQueue(player)
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.onMatchEnded()
	if pendingMatch then
		local modeId = pendingMatch.modeId
		pendingMatch = nil
		tryStartMatch(modeId)
		return
	end

	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.onArenaBusyChanged()
	if MatchStateService.isArenaBusy() then
		return
	end

	if pendingMatch then
		local modeId = pendingMatch.modeId
		pendingMatch = nil
		tryStartMatch(modeId)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

return MatchmakingService
