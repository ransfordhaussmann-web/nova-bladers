local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local callbacks = {}

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {
			players = {},
			fillToken = 0,
		}
	end
end

initQueues()

local function getQueueSize(modeId)
	return #queues[modeId].players
end

local function buildUpdatePayload(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local count = getQueueSize(modeId)
	local status = "waiting"
	local statusText = string.format("Warte auf Spieler (%d/%d)", count, mode.minPlayers)

	if arenaBusy and count >= mode.minPlayers then
		status = "pending"
		statusText = "Arena belegt — du bist als Nächster dran"
	elseif count >= mode.minPlayers and mode.fillTimeout > 0 and count < mode.maxPlayers then
		status = "filling"
		statusText = string.format("Warteschlange füllt sich (%d/%d)", count, mode.maxPlayers)
	elseif count >= mode.minPlayers then
		status = "ready"
		statusText = "Match startet gleich..."
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		statusText = statusText,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = {}
	for _, queuedPlayer in queues[modeId].players do
		payload[queuedPlayer] = buildUpdatePayload(queuedPlayer, modeId)
	end
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(payload)
	end
end

local function clearPlayerFromQueues(player)
	local previousMode = playerQueue[player]
	if not previousMode then
		return
	end

	local queue = queues[previousMode]
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end
	playerQueue[player] = nil

	if callbacks.onQueueLeft then
		callbacks.onQueueLeft(player)
	end
	broadcastQueueUpdate(previousMode)
end

local function popMatchPlayers(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue.players, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local nextPlayer = table.remove(queue.players, 1)
		if nextPlayer and nextPlayer.Parent then
			table.insert(matchPlayers, nextPlayer)
			playerQueue[nextPlayer] = nil
			if callbacks.onQueueLeft then
				callbacks.onQueueLeft(nextPlayer)
			end
		end
	end

	queue.fillToken += 1
	return matchPlayers
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	if count < mode.minPlayers or arenaBusy then
		return
	end

	local players = popMatchPlayers(modeId)
	if #players < mode.minPlayers then
		return
	end

	arenaBusy = true
	broadcastQueueUpdate(modeId)

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

local function scheduleFillTimeout(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	local queue = queues[modeId]
	queue.fillToken += 1
	local token = queue.fillToken

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		tryStartMatch(modeId)
	end)
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		for modeId in MatchmakingConfig.MODES do
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
		modeId = MatchmakingConfig.getRecommendedModeId(1)
	end

	if playerQueue[player] == modeId then
		if callbacks.onQueueUpdateSingle then
			callbacks.onQueueUpdateSingle(player, buildUpdatePayload(player, modeId))
		end
		return
	end

	clearPlayerFromQueues(player)

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	local mode = MatchmakingConfig.getMode(modeId)
	if callbacks.onQueueUpdateSingle then
		callbacks.onQueueUpdateSingle(player, buildUpdatePayload(player, modeId))
	end
	broadcastQueueUpdate(modeId)

	if #queue.players >= mode.minPlayers then
		if mode.fillTimeout > 0 and #queue.players < mode.maxPlayers then
			scheduleFillTimeout(modeId)
		else
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.leaveQueue(player)
	clearPlayerFromQueues(player)
end

function MatchmakingService.removePlayer(player)
	clearPlayerFromQueues(player)
end

function MatchmakingService.registerCallbacks(newCallbacks)
	callbacks = newCallbacks
end

return MatchmakingService
