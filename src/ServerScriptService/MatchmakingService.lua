local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTimers = {}
local pendingMatch = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueue(player, modeId)
	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			return true
		end
	end
	return false
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function getQueueSnapshot(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	return {
		modeId = modeId,
		label = config.label,
		count = #queue,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		fillTimeout = config.fillTimeout,
	}
end

local listeners = {
	onQueueUpdate = nil,
	onMatchReady = nil,
}

function MatchmakingService.setListeners(newListeners)
	listeners = newListeners
end

local function broadcastQueueUpdate(player, payload)
	if listeners.onQueueUpdate then
		listeners.onQueueUpdate(player, payload)
	end
end

local function broadcastModeQueue(modeId)
	local snapshot = getQueueSnapshot(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			broadcastQueueUpdate(player, {
				inQueue = true,
				pending = false,
				mode = snapshot,
			})
		end
	end
end

local function sendIdle(player)
	broadcastQueueUpdate(player, {
		inQueue = false,
		pending = false,
	})
end

local function extractReadyPlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, config.maxPlayers)
	local ready = {}
	for i = 1, count do
		table.insert(ready, queue[i])
	end
	for i = count, 1, -1 do
		table.remove(queue, i)
	end
	for _, player in ready do
		playerMode[player] = nil
	end
	clearFillTimer(modeId)
	return ready
end

local function tryLaunchMatch(modeId, players)
	if #players == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = players,
		}
		for _, player in players do
			if player.Parent then
				broadcastQueueUpdate(player, {
					inQueue = true,
					pending = true,
					mode = getQueueSnapshot(modeId),
				})
			end
		end
		return
	end

	pendingMatch = nil
	if listeners.onMatchReady then
		listeners.onMatchReady(modeId, players)
	end
end

local function evaluateQueue(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = #queue

	if count >= config.maxPlayers then
		tryLaunchMatch(modeId, extractReadyPlayers(modeId))
		return
	end

	if count >= config.minPlayers and not config.fillTimeout then
		tryLaunchMatch(modeId, extractReadyPlayers(modeId))
		return
	end

	if count >= config.minPlayers and config.fillTimeout and not fillTimers[modeId] then
		local token = {}
		fillTimers[modeId] = token
		broadcastModeQueue(modeId)

		task.delay(config.fillTimeout, function()
			if fillTimers[modeId] ~= token then
				return
			end
			fillTimers[modeId] = nil

			local current = queues[modeId]
			if #current >= config.minPlayers then
				tryLaunchMatch(modeId, extractReadyPlayers(modeId))
			end
		end)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		sendIdle(player)
		return
	end

	removeFromQueue(player, modeId)
	playerMode[player] = nil

	local config = getModeConfig(modeId)
	if config.fillTimeout and #queues[modeId] < config.minPlayers then
		clearFillTimer(modeId)
	end

	sendIdle(player)
	broadcastModeQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end

	if playerMode[player] == modeId then
		broadcastQueueUpdate(player, {
			inQueue = true,
			pending = pendingMatch ~= nil,
			mode = getQueueSnapshot(modeId),
		})
		return true
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	broadcastModeQueue(modeId)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.onArenaFreed()
	if pendingMatch then
		local snapshot = pendingMatch
		pendingMatch = nil
		tryLaunchMatch(snapshot.modeId, snapshot.players)
	end

	for modeId in MatchmakingConfig.MODES do
		evaluateQueue(modeId)
	end
end

local function removeFromPending(player)
	if not pendingMatch then
		return
	end

	local filtered = {}
	for _, p in pendingMatch.players do
		if p ~= player and p.Parent then
			table.insert(filtered, p)
		end
	end

	if #filtered == 0 then
		pendingMatch = nil
		return
	end

	pendingMatch.players = filtered
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromPending(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.getRecommendedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
