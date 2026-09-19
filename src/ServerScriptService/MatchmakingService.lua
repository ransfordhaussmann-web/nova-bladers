local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local callbacks = {}

for modeId, _ in pairs(MatchmakingConfig.MODES) do
	queues[modeId] = {
		players = {},
		fillDeadline = nil,
	}
end

local function getQueue(modeId)
	return queues[modeId]
end

local function playerInList(list, player)
	for i, queued in list do
		if queued == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = getQueue(modeId)
	local index = playerInList(queue.players, player)
	if index then
		table.remove(queue.players, index)
	end
	playerQueue[player] = nil

	if #queue.players < MatchmakingConfig.getMode(modeId).minPlayers then
		queue.fillDeadline = nil
	end

	return modeId
end

local function buildUpdatePayload(modeId, status)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local fillSecondsLeft

	if queue.fillDeadline then
		fillSecondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		current = #queue.players,
		required = mode.minPlayers,
		max = mode.maxPlayers,
		status = status or MatchmakingService.getQueueStatus(modeId),
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function notifyQueue(modeId)
	if not callbacks.onQueueUpdate then
		return
	end

	local queue = getQueue(modeId)
	local status = MatchmakingService.getQueueStatus(modeId)
	for _, player in queue.players do
		if player.Parent then
			callbacks.onQueueUpdate(player, buildUpdatePayload(modeId, status))
		end
	end
end

local function notifyPlayerLeft(player)
	if callbacks.onQueueLeft then
		callbacks.onQueueLeft(player)
	end
end

function MatchmakingService.getQueueStatus(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return "waiting"
	end

	local queue = getQueue(modeId)
	local count = #queue.players

	if count == 0 then
		return "waiting"
	end

	if MatchStateService.isArenaBusy() and count >= mode.minPlayers then
		return "pending"
	end

	if count >= mode.maxPlayers then
		return "ready"
	end

	if count >= mode.minPlayers then
		if mode.fillTimeout and queue.fillDeadline and os.clock() >= queue.fillDeadline then
			return "ready"
		end
		if not mode.fillTimeout then
			return "ready"
		end
		return "waiting"
	end

	return "waiting"
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		return true
	end

	removeFromQueue(player)
	playerQueue[player] = modeId

	local queue = getQueue(modeId)
	table.insert(queue.players, player)

	if #queue.players >= mode.minPlayers and mode.fillTimeout and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + mode.fillTimeout
	end

	notifyQueue(modeId)
	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = removeFromQueue(player)
	if modeId then
		notifyQueue(modeId)
	end
	notifyPlayerLeft(player)
	return true
end

function MatchmakingService.onPlayerRemoving(player)
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local status = MatchmakingService.getQueueStatus(modeId)
	if status ~= "ready" then
		if status == "pending" then
			notifyQueue(modeId)
		end
		return
	end

	if MatchStateService.isArenaBusy() then
		notifyQueue(modeId)
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(matchPlayers, queue.players[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
		notifyPlayerLeft(player)
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, matchPlayers)
	end

	for otherModeId, _ in pairs(MatchmakingConfig.MODES) do
		if otherModeId ~= modeId then
			notifyQueue(otherModeId)
		end
	end
end

function MatchmakingService.onArenaFreed()
	for modeId, _ in pairs(MatchmakingConfig.MODES) do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.tick()
	for modeId, _ in pairs(MatchmakingConfig.MODES) do
		MatchmakingService.tryStartMatch(modeId)
	end
end

return MatchmakingService
