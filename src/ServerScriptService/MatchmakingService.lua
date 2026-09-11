local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local preferredMode = {}
local arenaBusy = false
local fillTimers = {}
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueContains(modeId, player)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			return true
		end
	end
	return false
end

local function removeFromAllQueues(player)
	for modeId, queue in queues do
		for index, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, index)
				break
			end
		end
	end
	playerQueue[player] = nil
end

local function buildUpdatePayload(player, modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = queues[modeId]
	local count = #queue
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
		modeLabel = mode.label,
		position = position,
		count = count,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = arenaBusy and "pending" or "waiting",
	}
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		if player.Parent and callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(player, buildUpdatePayload(player, modeId))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function takePlayersFromQueue(modeId, count)
	local taken = {}
	local queue = queues[modeId]
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function tryStartMode(modeId)
	if arenaBusy then
		return
	end

	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	if not mode or #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			clearFillTimer(modeId)
			local players = takePlayersFromQueue(modeId, mode.maxPlayers)
			if #players >= mode.minPlayers and callbacks.onMatchReady then
				callbacks.onMatchReady(players, modeId)
			end
			broadcastQueueUpdate(modeId)
			return
		end

		if not fillTimers[modeId] and #queue >= mode.minPlayers then
			fillTimers[modeId] = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				if arenaBusy then
					return
				end
				local currentQueue = queues[modeId]
				if #currentQueue < mode.minPlayers then
					return
				end
				local players = takePlayersFromQueue(modeId, #currentQueue)
				if #players >= mode.minPlayers and callbacks.onMatchReady then
					callbacks.onMatchReady(players, modeId)
				end
				broadcastQueueUpdate(modeId)
				MatchmakingService.processQueues()
			end)
		end
		return
	end

	clearFillTimer(modeId)
	local players = takePlayersFromQueue(modeId, mode.maxPlayers)
	if #players >= mode.minPlayers and callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.registerHandlers(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId, _ in queues do
		broadcastQueueUpdate(modeId)
	end
	if not busy then
		MatchmakingService.processQueues()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.setPreferredMode(player, modeId)
	if getModeConfig(modeId) then
		preferredMode[player] = modeId
	end
end

function MatchmakingService.getPreferredMode(player)
	return preferredMode[player] or MatchmakingConfig.DEFAULT_MODE
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false, "invalid_player"
	end
	if not getModeConfig(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	preferredMode[player] = modeId

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, buildUpdatePayload(player, modeId))
	end
	broadcastQueueUpdate(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		if callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(player, { inQueue = false })
		end
		return
	end

	removeFromAllQueues(player)
	clearFillTimer(modeId)

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { inQueue = false })
	end
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.processQueues()
	if arenaBusy then
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		tryStartMode(modeId)
		if arenaBusy then
			break
		end
	end
end

function MatchmakingService.getQueueSnapshot(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return nil
	end
	return {
		modeId = modeId,
		count = #queues[modeId],
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	preferredMode[player] = nil
end)

return MatchmakingService
