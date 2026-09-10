local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local pendingMatch = nil
local arenaBusy = false
local remotes = nil
local onMatchReady = nil

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {
			players = {},
			fillToken = 0,
		}
	end
end

local function playerInList(list, player)
	for i, p in list do
		if p == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	local index = playerInList(queue.players, player)
	if index then
		table.remove(queue.players, index)
	end
	playerMode[player] = nil
end

local function buildQueuePayload(modeId, player)
	local queue = queues[modeId]
	local mode = MatchmakingConfig.getMode(modeId)
	local status = "waiting"

	if pendingMatch and pendingMatch.modeId == modeId and playerInList(pendingMatch.players, player) then
		status = if arenaBusy then "pending" else "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = playerInList(queue.players, player) or 0,
		queueSize = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdate()
	if not remotes then
		return
	end

	for modeId, queue in queues do
		for _, player in queue.players do
			if player.Parent then
				remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
			end
		end
	end

	if pendingMatch then
		for _, player in pendingMatch.players do
			if player.Parent and not playerMode[player] then
				remotes.QueueUpdate:FireClient(player, {
					modeId = pendingMatch.modeId,
					modeLabel = MatchmakingConfig.getMode(pendingMatch.modeId).label,
					position = 0,
					queueSize = #pendingMatch.players,
					minPlayers = MatchmakingConfig.getMode(pendingMatch.modeId).minPlayers,
					maxPlayers = MatchmakingConfig.getMode(pendingMatch.modeId).maxPlayers,
					status = if arenaBusy then "pending" else "ready",
					arenaBusy = arenaBusy,
				})
			end
		end
	end
end

local function clearPending()
	pendingMatch = nil
end

local function launchMatch(matchPlayers, modeId)
	for _, player in matchPlayers do
		playerMode[player] = nil
	end

	for modeIdKey, queue in queues do
		local filtered = {}
		for _, p in queue.players do
			if not playerInList(matchPlayers, p) then
				table.insert(filtered, p)
			end
		end
		queue.players = filtered
	end

	pendingMatch = {
		modeId = modeId,
		players = matchPlayers,
	}

	if arenaBusy then
		broadcastQueueUpdate()
		return
	end

	clearPending()
	if onMatchReady then
		onMatchReady(matchPlayers, modeId)
	end
end

local function tryStartMatch(modeId)
	local queue = queues[modeId]
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or #queue.players < mode.minPlayers then
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(matchPlayers, queue.players[i])
	end

	launchMatch(matchPlayers, modeId)
end

local function scheduleFillTimeout(modeId)
	local queue = queues[modeId]
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	queue.fillToken += 1
	local token = queue.fillToken

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		if #queue.players >= mode.minPlayers and #queue.players < mode.maxPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.init(config)
	remotes = config.remotes
	onMatchReady = config.onMatchReady
	initQueues()
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy and pendingMatch then
		local match = pendingMatch
		clearPending()
		if onMatchReady then
			onMatchReady(match.players, match.modeId)
		end
		return
	end
	broadcastQueueUpdate()
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.getMode(modeId) then
		return false, "invalid_mode"
	end

	removeFromQueue(player)

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerMode[player] = modeId

	local mode = MatchmakingConfig.getMode(modeId)
	if #queue.players == 1 and mode.fillTimeout then
		scheduleFillTimeout(modeId)
	end

	broadcastQueueUpdate()

	if #queue.players >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #queue.players >= mode.minPlayers and not mode.fillTimeout then
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] and not (pendingMatch and playerInList(pendingMatch.players, player)) then
		return false
	end

	if pendingMatch and playerInList(pendingMatch.players, player) then
		local filtered = {}
		for _, p in pendingMatch.players do
			if p ~= player then
				table.insert(filtered, p)
			end
		end
		if #filtered == 0 then
			clearPending()
		else
			pendingMatch.players = filtered
		end
	end

	removeFromQueue(player)
	broadcastQueueUpdate()
	return true
end

function MatchmakingService.isInQueue(player)
	return playerMode[player] ~= nil
		or (pendingMatch ~= nil and playerInList(pendingMatch.players, player) ~= nil)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.onMatchEnded()
	MatchmakingService.setArenaBusy(false)
	for modeId, queue in queues do
		if #queue.players > 0 then
			tryStartMatch(modeId)
		end
	end
end

return MatchmakingService
