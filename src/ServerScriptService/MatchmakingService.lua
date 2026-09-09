local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local fillTimers = {}
local pendingMatch = nil

local callbacks = {
	onQueueUpdate = nil,
	onMatchReady = nil,
	onPlayerEnterArena = nil,
}

for modeId in pairs(MatchmakingConfig.MODES) do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function buildQueuePayload(player, modeId)
	local queue = queues[modeId] or {}
	local mode = getMode(modeId)
	local pending = pendingMatch ~= nil and pendingMatch.modeId == modeId
	local fillDeadline = fillTimers[modeId]

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		queueSize = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		inQueue = playerEntry[player] ~= nil,
		pending = pending and MatchStateService.isArenaBusy(),
		fillSecondsLeft = fillDeadline and math.max(0, math.ceil(fillDeadline - os.clock())) or nil,
	}
end

local function notifyPlayer(player)
	if not callbacks.onQueueUpdate or not playerEntry[player] then
		return
	end
	local entry = playerEntry[player]
	callbacks.onQueueUpdate(player, buildQueuePayload(player, entry.modeId))
end

local function notifyQueue(modeId)
	for _, queuedPlayer in queues[modeId] do
		notifyPlayer(queuedPlayer)
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end
	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = os.clock() + mode.fillTimeout
	notifyQueue(modeId)

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] and os.clock() >= fillTimers[modeId] then
			clearFillTimer(modeId)
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	playerEntry[player] = nil

	for i, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			table.remove(queues[modeId], i)
			break
		end
	end

	local mode = getMode(modeId)
	if mode and #queues[modeId] < mode.minPlayers then
		clearFillTimer(modeId)
	end

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { inQueue = false })
	end
	notifyQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerEntry[player] then
		MatchmakingService.removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = { modeId = modeId }

	local mode = getMode(modeId)
	if mode and #queues[modeId] >= mode.minPlayers and mode.fillTimeout then
		startFillTimer(modeId)
	end

	notifyPlayer(player)
	notifyQueue(modeId)
	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		if #queues[modeId] > 0 then
			pendingMatch = { modeId = modeId }
			notifyQueue(modeId)
		end
		return false
	end

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not mode or #queue < mode.minPlayers then
		return false
	end

	if mode.fillTimeout and fillTimers[modeId] and os.clock() < fillTimers[modeId] and #queue < mode.maxPlayers then
		return false
	end

	local matchPlayers = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, matchPlayer in matchPlayers do
		MatchmakingService.removeFromQueue(matchPlayer)
	end
	clearFillTimer(modeId)
	pendingMatch = nil

	MatchStateService.setArenaBusy(true)

	if callbacks.onMatchReady then
		callbacks.onMatchReady(matchPlayers, modeId)
	end
	return true
end

function MatchmakingService.processPendingQueues()
	if MatchStateService.isArenaBusy() then
		return
	end

	for modeId in pairs(MatchmakingConfig.MODES) do
		if MatchmakingService.tryStartMatch(modeId) then
			return
		end
	end
end

function MatchmakingService.getPreferredModeForPlayerCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.registerHandlers(handlers)
	callbacks.onQueueUpdate = handlers.onQueueUpdate
	callbacks.onMatchReady = handlers.onMatchReady
	callbacks.onPlayerEnterArena = handlers.onPlayerEnterArena
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.removeFromQueue(player)
end

MatchStateService.onArenaFreed(function()
	MatchmakingService.processPendingQueues()
end)

return MatchmakingService
