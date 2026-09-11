local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local handlers = {}
local queues = {}
local playerMode = {}
local arenaBusy = false
local fillTimers = {}

for _, modeId in MatchmakingConfig.MODE_ORDER do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.getMode(modeId)
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
end

local function buildStatusMessage(modeId, queuedCount, status)
	local mode = getModeConfig(modeId)

	if status == "pending" then
		return "Arena belegt — du bist als Nächstes dran"
	end

	if status == "starting" then
		return "Match startet gleich..."
	end

	if modeId == "training" then
		return "Training startet..."
	end

	if modeId == "pvp" then
		return string.format("Warte auf Gegner (%d/%d)", queuedCount, mode.maxPlayers)
	end

	return string.format("FFA-Warteschlange (%d/%d)", queuedCount, mode.maxPlayers)
end

local function buildPlayerPayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return {
			inQueue = false,
			status = "idle",
			message = "",
		}
	end

	local queue = queues[modeId]
	local mode = getModeConfig(modeId)
	local queuedCount = #queue
	local position = 1

	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if arenaBusy and position <= mode.maxPlayers then
		status = "pending"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queuedCount = queuedCount,
		requiredCount = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		message = buildStatusMessage(modeId, queuedCount, status),
	}
end

local function broadcastQueueUpdates()
	if not handlers.onQueueUpdate then
		return
	end

	local seen = {}
	for _, queue in queues do
		for _, player in queue do
			if player.Parent and not seen[player] then
				seen[player] = true
				handlers.onQueueUpdate(player, buildPlayerPayload(player))
			end
		end
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
	return token
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}

	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end

	return taken
end

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	arenaBusy = true
	clearFillTimer(modeId)

	for _, player in players do
		if handlers.onPlayerEnterArena then
			handlers.onPlayerEnterArena(player)
		end
	end

	broadcastQueueUpdates()

	if handlers.onMatchReady then
		handlers.onMatchReady(players, modeId)
	end
end

local function tryStartMode(modeId)
	if arenaBusy then
		return
	end

	local queue = queues[modeId]
	local mode = getModeConfig(modeId)
	local queuedCount = #queue

	if modeId == "training" then
		if queuedCount >= 1 then
			startMatch(modeId, takePlayers(modeId, 1))
		end
		return
	end

	if modeId == "pvp" then
		if queuedCount >= 2 then
			startMatch(modeId, takePlayers(modeId, 2))
		end
		return
	end

	if modeId == "ffa" then
		if queuedCount >= mode.maxPlayers then
			startMatch(modeId, takePlayers(modeId, mode.maxPlayers))
			return
		end

		if queuedCount >= mode.minPlayers and not fillTimers[modeId] then
			local token = {}
			fillTimers[modeId] = token

			task.delay(mode.fillTimeout, function()
				if fillTimers[modeId] ~= token or arenaBusy then
					return
				end
				fillTimers[modeId] = nil

				local currentQueue = queues[modeId]
				if #currentQueue >= mode.minPlayers then
					startMatch(modeId, takePlayers(modeId, math.min(#currentQueue, mode.maxPlayers)))
				end
			end)
		end
	end
end

local function tryStartMatches()
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		tryStartMode(modeId)
		if arenaBusy then
			break
		end
	end
end

function MatchmakingService.register(newHandlers)
	handlers = newHandlers or {}
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
		if handlers.getRecommendedMode then
			modeId = handlers.getRecommendedMode()
		else
			modeId = MatchmakingConfig.DEFAULT_MODE
		end
	end

	if handlers.getPhase and handlers.getPhase(player) == "arena" then
		return buildPlayerPayload(player)
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	tryStartMatches()
	broadcastQueueUpdates()

	return buildPlayerPayload(player)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
	broadcastQueueUpdates()
	return buildPlayerPayload(player)
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
	clearFillTimer("ffa")
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		tryStartMatches()
	end
	broadcastQueueUpdates()
end

function MatchmakingService.getRecommendedMode(playerCount)
	playerCount = playerCount or 1
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.getPlayerPayload(player)
	return buildPlayerPayload(player)
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

return MatchmakingService
