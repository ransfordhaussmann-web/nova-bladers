local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local pendingMatch = nil
local arenaBusy = false
local onQueueUpdate = nil
local onMatchReady = nil
local queueSubscribers = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {
		players = {},
		fillDeadline = nil,
	}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function playerInList(list, player)
	for _, p in list do
		if p == player then
			return true
		end
	end
	return false
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i = #queue.players, 1, -1 do
		if queue.players[i] == player then
			table.remove(queue.players, i)
		end
	end

	if #queue.players < (getMode(modeId).minPlayers or 1) then
		queue.fillDeadline = nil
	end

	playerMode[player] = nil
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	return {
		modeId = modeId,
		label = mode.label,
		count = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillDeadline = queue.fillDeadline,
	}
end

local function broadcastQueueUpdates()
	if not onQueueUpdate then
		return
	end

	for subscribedPlayer, _ in queueSubscribers do
		if subscribedPlayer.Parent then
			local modeId = playerMode[subscribedPlayer]
			if modeId then
				local payload = buildQueuePayload(modeId)
				payload.pending = arenaBusy
				onQueueUpdate(subscribedPlayer, payload, true)
			end
		end
	end
end

local function sendPlayerUpdate(player, forcePending)
	if not onQueueUpdate or not player.Parent then
		return
	end

	local modeId = playerMode[player]
	if modeId then
		local payload = buildQueuePayload(modeId)
		payload.pending = forcePending or (arenaBusy and pendingMatch ~= nil)
		onQueueUpdate(player, payload, true)
	else
		onQueueUpdate(player, nil, true)
	end
end

local function notifyPendingPlayers()
	if not pendingMatch or not onQueueUpdate then
		return
	end

	local payload = buildQueuePayload(pendingMatch.modeId)
	payload.count = #pendingMatch.players
	payload.pending = true
	for _, player in pendingMatch.players do
		if player.Parent then
			onQueueUpdate(player, payload, true)
		end
	end
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end

	for _, player in taken do
		sendPlayerUpdate(player, arenaBusy)
	end
	queue.fillDeadline = nil
	return taken
end

local function shouldStartMode(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if mode.fillTimeout > 0 then
		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + mode.fillTimeout
			return false
		end
		return os.clock() >= queue.fillDeadline
	end

	return count >= mode.minPlayers
end

local function tryStartMatch()
	if arenaBusy or pendingMatch or not onMatchReady then
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		if shouldStartMode(modeId) then
			local mode = getMode(modeId)
			local players = takePlayers(modeId, mode.maxPlayers)
			if #players >= mode.minPlayers then
				pendingMatch = {
					modeId = modeId,
					players = players,
				}
				notifyPendingPlayers()
				return
			end
		end
	end
end

local function flushPendingMatch()
	if not pendingMatch or arenaBusy or not onMatchReady then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	onMatchReady(match.modeId, match.players)
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		tryStartMatch()
		flushPendingMatch()
	end
end

function MatchmakingService.setCallbacks(callbacks)
	onQueueUpdate = callbacks.onQueueUpdate
	onMatchReady = callbacks.onMatchReady
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return false, "invalid_mode"
	end

	removeFromQueue(player)

	local queue = queues[modeId]
	if #queue.players >= getMode(modeId).maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue.players, player)
	playerMode[player] = modeId
	queueSubscribers[player] = true

	if #queue.players >= getMode(modeId).minPlayers and getMode(modeId).fillTimeout > 0 and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + getMode(modeId).fillTimeout
	end

	broadcastQueueUpdates()
	sendPlayerUpdate(player)
	tryStartMatch()
	flushPendingMatch()

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return false
	end

	queueSubscribers[player] = nil
	removeFromQueue(player)
	broadcastQueueUpdates()
	sendPlayerUpdate(player)

	if pendingMatch and playerInList(pendingMatch.players, player) then
		for i, p in pendingMatch.players do
			if p == player then
				table.remove(pendingMatch.players, i)
				break
			end
		end
		if #pendingMatch.players < getMode(pendingMatch.modeId).minPlayers then
			for _, p in pendingMatch.players do
				MatchmakingService.joinQueue(p, pendingMatch.modeId)
			end
			pendingMatch = nil
		end
	end

	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.getQuickMatchMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.removePlayer(player)
	queueSubscribers[player] = nil
	MatchmakingService.leaveQueue(player)

	if pendingMatch then
		for i, p in pendingMatch.players do
			if p == player then
				table.remove(pendingMatch.players, i)
				break
			end
		end
		if #pendingMatch.players == 0 then
			pendingMatch = nil
		end
	end
end

function MatchmakingService.isPending()
	return pendingMatch ~= nil and arenaBusy
end

function MatchmakingService.tick()
	tryStartMatch()
	flushPendingMatch()
end

return MatchmakingService
