local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function queueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return nil
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	return modeId
end

local function buildUpdatePayload(player, modeId, status)
	local config = getModeConfig(modeId)
	local size = queueSize(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		status = status,
		queueSize = size,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function broadcastQueueUpdates(modeId)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			local status = MatchStateService.isBusy() and "pending" or "waiting"
			if callbacks.onQueueUpdate then
				callbacks.onQueueUpdate(queuedPlayer, buildUpdatePayload(queuedPlayer, modeId, status))
			end
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdates(modeId)
	end
end

local function canStartMode(modeId, allowFillTimeout)
	local config = getModeConfig(modeId)
	local size = queueSize(modeId)
	if size < config.minPlayers then
		return false
	end
	if size >= config.maxPlayers then
		return true
	end
	if config.fillTimeout > 0 and not allowFillTimeout then
		return false
	end
	return size >= config.minPlayers
end

local function popPlayersForMatch(modeId)
	local config = getModeConfig(modeId)
	local count = math.min(queueSize(modeId), config.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local nextPlayer = table.remove(queues[modeId], 1)
		if nextPlayer and nextPlayer.Parent then
			table.insert(matchPlayers, nextPlayer)
			playerQueue[nextPlayer] = nil
			if callbacks.onQueueUpdate then
				callbacks.onQueueUpdate(nextPlayer, { inQueue = false })
			end
		end
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	broadcastQueueUpdates(modeId)
	return matchPlayers
end

local function tryStartMatch(modeId, allowFillTimeout)
	if MatchStateService.isBusy() then
		broadcastQueueUpdates(modeId)
		return
	end

	if not canStartMode(modeId, allowFillTimeout) then
		return
	end

	MatchStateService.setBusy(true)

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers < getModeConfig(modeId).minPlayers then
		MatchStateService.setBusy(false)
		for _, player in matchPlayers do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	for _, player in matchPlayers do
		if callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(player, {
				inQueue = true,
				modeId = modeId,
				modeLabel = getModeConfig(modeId).label,
				status = "starting",
				queueSize = 0,
				minPlayers = getModeConfig(modeId).minPlayers,
				maxPlayers = getModeConfig(modeId).maxPlayers,
				arenaBusy = false,
			})
		end
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, matchPlayers)
	end
end

local function scheduleFillTimer(modeId)
	local config = getModeConfig(modeId)
	if config.fillTimeout <= 0 or fillTimers[modeId] then
		return
	end
	if queueSize(modeId) < config.minPlayers then
		return
	end

	fillTimers[modeId] = task.delay(config.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId, true)
	end)
end

local function tryAllQueues()
	for modeId in queues do
		if queueSize(modeId) > 0 then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false, "invalid_player"
	end

	if playerQueue[player] then
		return false, "already_queued"
	end

	modeId = modeId or MatchmakingConfig.DEFAULT_MODE
	if not queues[modeId] then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	local status = MatchStateService.isBusy() and "pending" or "waiting"
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, buildUpdatePayload(player, modeId, status))
	end
	broadcastQueueUpdates(modeId)

	tryStartMatch(modeId)
	scheduleFillTimer(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return false
	end

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { inQueue = false })
	end
	broadcastQueueUpdates(modeId)
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId or nil
end

function MatchmakingService.onArenaFreed()
	broadcastAllQueues()
	tryAllQueues()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

MatchStateService.onArenaFreed(function()
	MatchmakingService.onArenaFreed()
end)

return MatchmakingService
