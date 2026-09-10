local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local callbacks = {}
local fillTokens = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = { players = {}, fillDeadline = nil }
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isPlayerValid(player)
	return player and player.Parent ~= nil
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local alive = {}
	for _, player in queue.players do
		if isPlayerValid(player) then
			table.insert(alive, player)
		else
			playerQueue[player] = nil
		end
	end
	queue.players = alive
end

local function playerNames(players)
	local names = {}
	for _, player in players do
		table.insert(names, player.DisplayName)
	end
	return names
end

function MatchmakingService.setCallbacks(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
	end
	if not busy then
		MatchmakingService.processAll()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getQueueSnapshot(modeId)
	local mode = getMode(modeId)
	if not mode then
		return nil
	end
	pruneQueue(modeId)
	local queue = queues[modeId]
	local timeLeft
	if queue.fillDeadline then
		timeLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end
	return {
		modeId = modeId,
		label = mode.label,
		current = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		timeLeft = timeLeft,
		playerNames = playerNames(queue.players),
	}
end

function MatchmakingService.getPlayerState(player)
	local modeId = playerQueue[player]
	if modeId then
		return {
			status = arenaBusy and "pending" or "queued",
			modeId = modeId,
			arenaBusy = arenaBusy,
			queue = MatchmakingService.getQueueSnapshot(modeId),
		}
	end
	return { status = "none" }
end

local function notifyPlayer(player, payload)
	if callbacks.onQueueUpdate and isPlayerValid(player) then
		callbacks.onQueueUpdate(player, payload)
	end
end

local function broadcastQueue(modeId)
	pruneQueue(modeId)
	local snapshot = MatchmakingService.getQueueSnapshot(modeId)
	for _, player in queues[modeId].players do
		notifyPlayer(player, {
			status = arenaBusy and "pending" or "queued",
			modeId = modeId,
			arenaBusy = arenaBusy,
			queue = snapshot,
		})
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue.players < getMode(modeId).minPlayers then
		queue.fillDeadline = nil
		fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	end

	broadcastQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	notifyPlayer(player, { status = "none" })
	return true
end

local function addToQueue(player, modeId)
	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isPlayerValid(player) then
		return false, "invalid_player"
	end

	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true, "already_queued"
		end
		removeFromQueue(player)
	end

	addToQueue(player, modeId)
	MatchmakingService.processQueue(modeId)
	return true, "joined"
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, count do
		local player = table.remove(queue.players, 1)
		if not player then
			break
		end
		playerQueue[player] = nil
		table.insert(taken, player)
	end
	queue.fillDeadline = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	return taken
end

local function scheduleFillCheck(modeId, delay)
	local token = (fillTokens[modeId] or 0) + 1
	fillTokens[modeId] = token
	task.delay(delay, function()
		if fillTokens[modeId] ~= token then
			return
		end
		MatchmakingService.processQueue(modeId)
	end)
end

function MatchmakingService.processQueue(modeId)
	pruneQueue(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	if count == 0 or arenaBusy then
		return
	end

	if count >= mode.maxPlayers then
		local players = takePlayers(modeId, mode.maxPlayers)
		if callbacks.onMatchReady and #players > 0 then
			callbacks.onMatchReady(modeId, players)
		end
		return
	end

	if count >= mode.minPlayers then
		if not mode.fillTimeout then
			local players = takePlayers(modeId, count)
			if callbacks.onMatchReady and #players > 0 then
				callbacks.onMatchReady(modeId, players)
			end
			return
		end

		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + mode.fillTimeout
			broadcastQueue(modeId)
			scheduleFillCheck(modeId, mode.fillTimeout)
			return
		end

		if os.clock() >= queue.fillDeadline then
			local players = takePlayers(modeId, count)
			if callbacks.onMatchReady and #players > 0 then
				callbacks.onMatchReady(modeId, players)
			end
		end
	end
end

function MatchmakingService.processAll()
	for modeId in MatchmakingConfig.MODES do
		MatchmakingService.processQueue(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
