--[[
	MatchmakingService — per-mode queues with fill timeout and arena-busy pending.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTokens = {}
local fillEndsAt = {}
local arenaBusy = false
local pendingMatch = nil
local callbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player, modeId)
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			return true
		end
	end
	return false
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillEndsAt[modeId] = nil
end

local function buildUpdatePayload(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queueSize = getQueueSize(modeId)
	local status = "waiting"

	if arenaBusy then
		status = "pending"
	elseif mode.minPlayers == 1 and queueSize >= 1 then
		status = "ready"
	elseif queueSize >= mode.maxPlayers then
		status = "ready"
	elseif queueSize >= mode.minPlayers and fillEndsAt[modeId] then
		status = "filling"
	end

	local fillSecondsLeft = nil
	if fillEndsAt[modeId] then
		fillSecondsLeft = math.max(0, math.ceil(fillEndsAt[modeId] - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		queueSize = queueSize,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillSecondsLeft = fillSecondsLeft,
		arenaBusy = arenaBusy,
	}
end

local function notifyPlayer(player)
	local modeId = playerMode[player]
	if not modeId then
		if callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(player, { status = "idle" })
		end
		return
	end
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, buildUpdatePayload(player, modeId))
	end
end

local function notifyQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			notifyPlayer(player)
		end
	end
end

local function collectReadyPlayers(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local players = {}
	for i = 1, count do
		table.insert(players, queue[i])
	end
	return players
end

local function clearPlayersFromQueue(modeId, players)
	local removeSet = {}
	for _, player in players do
		removeSet[player] = true
		playerMode[player] = nil
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if removeSet[queue[i]] then
			table.remove(queue, i)
		end
	end

	cancelFillTimer(modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queueSize = getQueueSize(modeId)
	if queueSize < mode.minPlayers then
		return
	end

	local ready = false
	if queueSize >= mode.maxPlayers then
		ready = true
	elseif mode.minPlayers == 1 and queueSize >= 1 then
		ready = true
	elseif fillEndsAt[modeId] and os.clock() >= fillEndsAt[modeId] then
		ready = true
	end

	if not ready then
		return
	end

	local players = collectReadyPlayers(modeId)
	if #players < mode.minPlayers then
		return
	end

	clearPlayersFromQueue(modeId, players)

	if arenaBusy then
		pendingMatch = { modeId = modeId, players = players }
		for _, player in players do
			if callbacks.onQueueUpdate then
				callbacks.onQueueUpdate(player, {
					status = "pending",
					modeId = modeId,
					modeLabel = mode.label,
					arenaBusy = true,
				})
			end
		end
		return
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

local function startFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if mode.fillTimeout <= 0 then
		tryStartMatch(modeId)
		return
	end

	if fillEndsAt[modeId] then
		return
	end

	fillEndsAt[modeId] = os.clock() + mode.fillTimeout
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.spawn(function()
		task.wait(mode.fillTimeout)
		if fillTokens[modeId] ~= token then
			return
		end
		tryStartMatch(modeId)
	end)

	notifyQueue(modeId)
end

local function evaluateQueue(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queueSize = getQueueSize(modeId)

	if queueSize >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if mode.minPlayers == 1 and queueSize >= 1 then
		tryStartMatch(modeId)
		return
	end

	if queueSize >= mode.minPlayers then
		startFillTimer(modeId)
		return
	end

	cancelFillTimer(modeId)
	notifyQueue(modeId)
end

function MatchmakingService.registerHandlers(handlers)
	callbacks = handlers or {}
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if busy then
		return
	end

	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		if callbacks.onMatchReady then
			callbacks.onMatchReady(match.players, match.modeId)
		end
		return
	end

	for modeId in MatchmakingConfig.MODES do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.isInQueue(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return false
	end

	playerMode[player] = nil
	removeFromQueue(player, modeId)

	local mode = MatchmakingConfig.getMode(modeId)
	if getQueueSize(modeId) < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	notifyPlayer(player)
	evaluateQueue(modeId)
	notifyQueue(modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.isValidMode(modeId) then
		return false, "invalid_mode"
	end

	if playerMode[player] == modeId then
		notifyPlayer(player)
		return true
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	notifyPlayer(player)
	evaluateQueue(modeId)
	notifyQueue(modeId)
	return true
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.getRecommendedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
