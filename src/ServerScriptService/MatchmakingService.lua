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
local onQueueUpdate
local onMatchReady

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildPlayerSnapshot(player)
	local modeId = playerMode[player]
	if not modeId then
		return {
			inQueue = false,
		}
	end

	local queue = queues[modeId]
	local config = getModeConfig(modeId)
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		position = position,
		queueSize = #queue,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
		pending = MatchStateService.isBusy(),
	}
end

function MatchmakingService.setCallbacks(callbacks)
	onQueueUpdate = callbacks.onQueueUpdate
	onMatchReady = callbacks.onMatchReady
end

function MatchmakingService.getSnapshot(player)
	return buildPlayerSnapshot(player)
end

function MatchmakingService.broadcastQueue(player)
	if onQueueUpdate then
		onQueueUpdate(player, buildPlayerSnapshot(player))
	end
end

function MatchmakingService.broadcastAllQueued()
	for player, _ in playerMode do
		if player.Parent then
			MatchmakingService.broadcastQueue(player)
		end
	end
end

local function popPlayers(modeId)
	local queue = queues[modeId]
	local config = getModeConfig(modeId)
	local count = math.min(#queue, config.maxPlayers)
	local players = {}

	for _ = 1, count do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer then
			playerMode[nextPlayer] = nil
			table.insert(players, nextPlayer)
		end
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	return players
end

local function startMatch(modeId, players)
	if #players == 0 or not onMatchReady then
		return
	end

	MatchStateService.setBusy(true)
	onMatchReady({
		mode = modeId,
		players = players,
	})
end

local function tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		MatchmakingService.broadcastAllQueued()
		return
	end

	if config.fillTimeout > 0 and not fillTimers[modeId] then
		fillTimers[modeId] = task.delay(config.fillTimeout, function()
			fillTimers[modeId] = nil
			if MatchStateService.isBusy() then
				MatchmakingService.broadcastAllQueued()
				return
			end
			local players = popPlayers(modeId)
			if #players >= config.minPlayers then
				startMatch(modeId, players)
			end
			MatchmakingService.broadcastAllQueued()
		end)
		MatchmakingService.broadcastAllQueued()
		return
	end

	if config.fillTimeout == 0 then
		local players = popPlayers(modeId)
		startMatch(modeId, players)
		MatchmakingService.broadcastAllQueued()
	end
end

function MatchmakingService.join(player, modeId)
	local config = getModeConfig(modeId)
	if not config then
		return false
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	MatchmakingService.broadcastQueue(player)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leave(player)
	if not playerMode[player] then
		return false
	end

	removeFromQueue(player)
	MatchmakingService.broadcastQueue(player)
	return true
end

function MatchmakingService.handlePlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.handleMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(function()
		for modeId, _ in queues do
			tryStartMatch(modeId)
		end
	end)
end

MatchStateService.onArenaFree(function()
	for modeId, _ in queues do
		tryStartMatch(modeId)
	end
end)

return MatchmakingService
