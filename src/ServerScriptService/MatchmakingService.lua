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

local playerMode = {}
local fillTimers = {}
local callbacks = {}

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function notifyQueueUpdate()
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate()
	end
end

local function cancelFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		token.cancelled = true
		fillTimers[modeId] = nil
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	local config = getModeConfig(modeId)
	if config and #queue < config.minPlayers then
		cancelFillTimer(modeId)
	end

	notifyQueueUpdate()
end

local function buildSnapshot(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local config = getModeConfig(modeId)
	if not config then
		return nil
	end

	local queue = queues[modeId]
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		count = #queue,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		position = position,
		pending = MatchStateService.isArenaBusy(),
		fillTimeout = config.fillTimeout,
	}
end

local function startMatch(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	local players = {}
	local takeCount = math.min(#queue, config.maxPlayers)
	for index = 1, takeCount do
		table.insert(players, queue[index])
	end

	queues[modeId] = {}
	cancelFillTimer(modeId)

	for _, matchPlayer in players do
		playerMode[matchPlayer] = nil
	end

	MatchStateService.setArenaBusy(true)
	notifyQueueUpdate()

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	if config.fillTimeout <= 0 or #queue >= config.maxPlayers then
		startMatch(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = { cancelled = false }
	fillTimers[modeId] = token
	task.spawn(function()
		task.wait(config.fillTimeout)
		if token.cancelled or MatchStateService.isArenaBusy() then
			if fillTimers[modeId] == token then
				fillTimers[modeId] = nil
			end
			return
		end

		if #queues[modeId] >= config.minPlayers then
			startMatch(modeId)
		elseif fillTimers[modeId] == token then
			fillTimers[modeId] = nil
		end
	end)
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false
	end

	if not modeId or not getModeConfig(modeId) then
		modeId = getRecommendedModeId()
	end

	removePlayerFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	notifyQueueUpdate()
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	removePlayerFromQueue(player)
end

function MatchmakingService.getPlayerSnapshot(player)
	return buildSnapshot(player)
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
	notifyQueueUpdate()
end

function MatchmakingService.onPlayerRemoving(player)
	removePlayerFromQueue(player)
end

function MatchmakingService.setCallbacks(newCallbacks)
	callbacks = newCallbacks or {}
end

return MatchmakingService
