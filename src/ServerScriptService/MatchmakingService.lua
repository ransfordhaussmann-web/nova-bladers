local Players = game:GetService("Players")

local MatchmakingConfig = require(game:GetService("ReplicatedStorage").NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntries = {}
local arenaBusy = false
local ffaFillToken = 0
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueueList(queue, player)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function buildQueueUpdate(player)
	local entry = playerEntries[player]
	if not entry then
		return { inQueue = false }
	end

	local config = getModeConfig(entry.mode)
	local queue = queues[entry.mode]
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local message
	if entry.status == "pending" then
		message = "Arena belegt — du bist als Nächstes dran"
	elseif entry.mode == "training" then
		message = "Starte Training..."
	elseif entry.mode == "pvp" then
		message = string.format("Warte auf Gegner (%d/%d)", #queue, config.minPlayers)
	elseif entry.mode == "ffa" then
		message = string.format("Sammle Spieler (%d–%d)", #queue, config.maxPlayers)
	end

	return {
		inQueue = true,
		mode = entry.mode,
		modeLabel = config.label,
		position = position,
		queueSize = #queue,
		required = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = entry.status,
		message = message,
	}
end

local function notifyPlayer(player)
	if callbacks.onQueueUpdate and player.Parent then
		callbacks.onQueueUpdate(player, buildQueueUpdate(player))
	end
end

local function notifyQueue(modeId)
	for _, queuedPlayer in queues[modeId] do
		notifyPlayer(queuedPlayer)
	end
end

local function clearPlayerEntry(player)
	local entry = playerEntries[player]
	if not entry then
		return
	end
	removeFromQueueList(queues[entry.mode], player)
	playerEntries[player] = nil
end

local function popPlayers(modeId, count)
	local picked = {}
	local queue = queues[modeId]
	for _ = 1, math.min(count, #queue) do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			table.insert(picked, nextPlayer)
			playerEntries[nextPlayer] = nil
		end
	end
	return picked
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		MatchmakingService.promotePendingPlayers()
		MatchmakingService.tryAllQueues()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.registerHandlers(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.getRecommendedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.leaveQueue(player)
	if not playerEntries[player] then
		notifyPlayer(player)
		return false
	end

	local modeId = playerEntries[player].mode
	clearPlayerEntry(player)
	notifyPlayer(player)
	notifyQueue(modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end
	if playerEntries[player] then
		MatchmakingService.leaveQueue(player)
	end

	local status = arenaBusy and "pending" or "waiting"
	table.insert(queues[modeId], player)
	playerEntries[player] = {
		mode = modeId,
		status = status,
	}

	notifyPlayer(player)
	notifyQueue(modeId)

	if not arenaBusy then
		MatchmakingService.tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.promotePendingPlayers()
	for _, entry in playerEntries do
		if entry.status == "pending" then
			entry.status = "waiting"
		end
	end
	for modeId in queues do
		notifyQueue(modeId)
	end
end

function MatchmakingService.tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not config or #queue == 0 then
		return
	end

	if modeId == "training" then
		MatchmakingService.launchMatch(modeId, popPlayers(modeId, 1))
		return
	end

	if modeId == "pvp" and #queue >= config.minPlayers then
		MatchmakingService.launchMatch(modeId, popPlayers(modeId, config.maxPlayers))
		return
	end

	if modeId == "ffa" and #queue >= config.maxPlayers then
		MatchmakingService.launchMatch(modeId, popPlayers(modeId, config.maxPlayers))
		return
	end

	if modeId == "ffa" and #queue >= config.minPlayers then
		ffaFillToken += 1
		local token = ffaFillToken
		task.delay(config.fillTimeout, function()
			if token ~= ffaFillToken or arenaBusy then
				return
			end
			if #queues.ffa >= config.minPlayers then
				MatchmakingService.launchMatch("ffa", popPlayers("ffa", math.min(#queues.ffa, config.maxPlayers)))
			end
		end)
	end
end

function MatchmakingService.tryAllQueues()
	for _, modeId in { "training", "pvp", "ffa" } do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.launchMatch(modeId, playerList)
	if arenaBusy or #playerList == 0 then
		for _, queuedPlayer in playerList do
			if queuedPlayer.Parent and not playerEntries[queuedPlayer] then
				table.insert(queues[modeId], queuedPlayer)
				playerEntries[queuedPlayer] = {
					mode = modeId,
					status = "waiting",
				}
			end
		end
		return
	end

	local activePlayers = {}
	for _, queuedPlayer in playerList do
		if queuedPlayer.Parent then
			table.insert(activePlayers, queuedPlayer)
		end
	end

	if #activePlayers == 0 then
		return
	end

	ffaFillToken += 1
	arenaBusy = true

	for _, queuedPlayer in activePlayers do
		notifyPlayer(queuedPlayer)
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, activePlayers)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	local modeId = playerEntries[player] and playerEntries[player].mode
	clearPlayerEntry(player)
	if modeId then
		notifyQueue(modeId)
	end
end

function MatchmakingService.getQueueState(player)
	return buildQueueUpdate(player)
end

return MatchmakingService
