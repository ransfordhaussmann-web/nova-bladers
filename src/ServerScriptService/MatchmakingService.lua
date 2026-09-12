--[[
	MatchmakingService — per-mode queues with fill timeout and arena-busy pending.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local fillTimers = {}
local pendingMatch = nil
local arenaBusy = false

local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueIndex(modeId, player)
	local queue = queues[modeId]
	if not queue then
		return nil
	end
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local index = queueIndex(entry.modeId, player)
	if index then
		table.remove(queues[entry.modeId], index)
	end

	if #queues[entry.modeId] < getModeConfig(entry.modeId).minPlayers then
		MatchmakingService.cancelFillTimer(entry.modeId)
	end

	playerEntry[player] = nil
end

local function buildUpdatePayload(modeId, player)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local entry = playerEntry[player]
	local status = entry and entry.status or "idle"

	return {
		modeId = modeId,
		modeLabel = config.label,
		queued = #queue,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		fillSecondsRemaining = fillTimers[modeId]
			and math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
			or nil,
		inQueue = entry ~= nil,
	}
end

local function notifyPlayer(player)
	local entry = playerEntry[player]
	if not entry or not player.Parent then
		return
	end
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, buildUpdatePayload(entry.modeId, player))
	end
end

local function notifyQueue(modeId)
	for _, player in queues[modeId] do
		notifyPlayer(player)
	end
end

local function setPlayerStatus(player, status)
	local entry = playerEntry[player]
	if entry then
		entry.status = status
		notifyPlayer(player)
	end
end

local function setQueueStatus(modeId, status)
	for _, player in queues[modeId] do
		setPlayerStatus(player, status)
	end
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		MatchmakingService.tryStartPendingMatch()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId or nil
end

function MatchmakingService.getPlayerStatus(player)
	local entry = playerEntry[player]
	return entry and entry.status or nil
end

function MatchmakingService.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return false
	end

	if entry.status == "pending" and pendingMatch then
		local filtered = {}
		for _, queuedPlayer in pendingMatch.players do
			if queuedPlayer ~= player then
				table.insert(filtered, queuedPlayer)
			end
		end
		pendingMatch.players = filtered
		if #filtered == 0 then
			pendingMatch = nil
		end
		playerEntry[player] = nil
		if callbacks.onLeaveQueue then
			callbacks.onLeaveQueue(player)
		end
		return true
	end

	local modeId = entry.modeId
	removeFromQueue(player)
	notifyQueue(modeId)

	if callbacks.onLeaveQueue then
		callbacks.onLeaveQueue(player)
	end

	return true
end

function MatchmakingService.cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if not timer then
		return
	end
	fillTimers[modeId] = nil
	if timer.thread then
		task.cancel(timer.thread)
	end
end

local function extractPlayers(modeId)
	local queue = queues[modeId]
	local players = table.clone(queue)
	queues[modeId] = {}
	MatchmakingService.cancelFillTimer(modeId)

	for _, player in players do
		playerEntry[player] = nil
	end

	return players
end

local function fireMatchReady(modeId, players)
	arenaBusy = true
	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, players)
	end
end

function MatchmakingService.tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return false
	end

	local players = extractPlayers(modeId)
	if arenaBusy then
		pendingMatch = { modeId = modeId, players = players }
		for _, player in players do
			playerEntry[player] = { modeId = modeId, status = "pending" }
			notifyPlayer(player)
		end
		return true
	end

	fireMatchReady(modeId, players)
	return true
end

function MatchmakingService.tryStartPendingMatch()
	if not pendingMatch or arenaBusy then
		return false
	end

	local match = pendingMatch
	pendingMatch = nil

	for _, player in match.players do
		playerEntry[player] = nil
	end

	fireMatchReady(match.modeId, match.players)
	return true
end

function MatchmakingService.startFillTimer(modeId)
	local config = getModeConfig(modeId)
	if config.fillTimeout <= 0 then
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	local endsAt = os.clock() + config.fillTimeout
	fillTimers[modeId] = { endsAt = endsAt }

	fillTimers[modeId].thread = task.delay(config.fillTimeout, function()
		fillTimers[modeId] = nil
		if #queues[modeId] >= config.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
		else
			setQueueStatus(modeId, "queued")
			notifyQueue(modeId)
		end
	end)

	setQueueStatus(modeId, "filling")
	notifyQueue(modeId)
end

function MatchmakingService.onQueueChanged(modeId)
	local config = getModeConfig(modeId)
	local count = #queues[modeId]

	if count >= config.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if count >= config.minPlayers then
		if config.fillTimeout > 0 then
			MatchmakingService.startFillTimer(modeId)
		else
			MatchmakingService.tryStartMatch(modeId)
		end
		return
	end

	setQueueStatus(modeId, "queued")
	notifyQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	local config = getModeConfig(modeId)
	if not config then
		return false, "invalid_mode"
	end

	if arenaBusy and playerEntry[player] and playerEntry[player].status == "pending" then
		return false, "pending"
	end

	if playerEntry[player] then
		if playerEntry[player].modeId == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = { modeId = modeId, status = "queued" }

	if callbacks.onJoinQueue then
		callbacks.onJoinQueue(player, modeId)
	end

	notifyQueue(modeId)
	MatchmakingService.onQueueChanged(modeId)
	return true
end

function MatchmakingService.resolveQuickMatchMode()
	for _, modeId in MatchmakingConfig.QUICK_MATCH_PRIORITY do
		if #queues[modeId] > 0 then
			return modeId
		end
	end
	return MatchmakingConfig.DEFAULT_MODE
end

function MatchmakingService.clearPlayer(player)
	removeFromQueue(player)
	if pendingMatch then
		local filtered = {}
		for _, queuedPlayer in pendingMatch.players do
			if queuedPlayer ~= player then
				table.insert(filtered, queuedPlayer)
			end
		end
		pendingMatch.players = filtered
		if #filtered == 0 then
			pendingMatch = nil
		end
	end
end

return MatchmakingService
