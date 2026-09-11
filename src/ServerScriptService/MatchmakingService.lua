local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local arenaBusy = false
local fillTimers = {}
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countValidPlayers(list)
	local count = 0
	for _, player in list do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function compactQueue(modeId)
	local modeQueue = queues[modeId]
	local compacted = {}
	for _, player in modeQueue do
		if player.Parent then
			table.insert(compacted, player)
		else
			playerEntry[player] = nil
		end
	end
	queues[modeId] = compacted
end

local function cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function buildPlayerSnapshot(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end

	local modeId = entry.modeId
	local modeConfig = getModeConfig(modeId)
	compactQueue(modeId)

	return {
		modeId = modeId,
		modeLabel = modeConfig.label,
		position = table.find(queues[modeId], player) or 0,
		queueSize = countValidPlayers(queues[modeId]),
		minPlayers = modeConfig.minPlayers,
		maxPlayers = modeConfig.maxPlayers,
		pending = arenaBusy,
		inQueue = true,
	}
end

local function broadcastQueueUpdate()
	if not callbacks.onQueueUpdate then
		return
	end

	for player, _ in playerEntry do
		if player.Parent then
			local snapshot = buildPlayerSnapshot(player)
			if snapshot then
				callbacks.onQueueUpdate(player, snapshot)
			end
		end
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	playerEntry[player] = nil

	local modeQueue = queues[modeId]
	for index, queuedPlayer in modeQueue do
		if queuedPlayer == player then
			table.remove(modeQueue, index)
			break
		end
	end

	compactQueue(modeId)
	local modeConfig = getModeConfig(modeId)
	if countValidPlayers(queues[modeId]) < modeConfig.minPlayers then
		cancelFillTimer(modeId)
	end
end

local function markPlayersInArena(playerList)
	for _, player in playerList do
		playerEntry[player] = nil
		if callbacks.onLeaveHub then
			callbacks.onLeaveHub(player)
		end
	end
end

local function startMatch(modeId, playerList)
	arenaBusy = true
	cancelFillTimer(modeId)
	queues[modeId] = {}
	markPlayersInArena(playerList)

	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, playerList)
	end

	broadcastQueueUpdate()
end

local function tryStartMode(modeId)
	if arenaBusy then
		return false
	end

	local modeConfig = getModeConfig(modeId)
	if not modeConfig then
		return false
	end

	compactQueue(modeId)
	local modeQueue = queues[modeId]
	local size = countValidPlayers(modeQueue)
	if size < modeConfig.minPlayers then
		return false
	end

	if modeConfig.fillTimeout > 0 and size < modeConfig.maxPlayers then
		if not fillTimers[modeId] then
			fillTimers[modeId] = task.delay(modeConfig.fillTimeout, function()
				fillTimers[modeId] = nil
				if arenaBusy then
					return
				end
				compactQueue(modeId)
				local readySize = countValidPlayers(queues[modeId])
				if readySize >= modeConfig.minPlayers then
					local players = {}
					for index = 1, math.min(readySize, modeConfig.maxPlayers) do
						table.insert(players, queues[modeId][index])
					end
					startMatch(modeId, players)
				end
			end)
		end
		return false
	end

	local players = {}
	for index = 1, math.min(size, modeConfig.maxPlayers) do
		table.insert(players, modeQueue[index])
	end
	startMatch(modeId, players)
	return true
end

local START_ORDER = { "ffa", "pvp", "training" }

local function tryStartAllQueues()
	for _, modeId in START_ORDER do
		if tryStartMode(modeId) then
			break
		end
	end
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
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

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local modeConfig = getModeConfig(modeId)
	if not modeConfig then
		return false, "unknown_mode"
	end

	if playerEntry[player] and playerEntry[player].modeId == modeId then
		broadcastQueueUpdate()
		return true
	end

	removeFromQueue(player)
	playerEntry[player] = { modeId = modeId }
	table.insert(queues[modeId], player)

	tryStartMode(modeId)
	broadcastQueueUpdate()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return false
	end

	removeFromQueue(player)
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { inQueue = false })
	end
	broadcastQueueUpdate()
	return true
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	tryStartAllQueues()
	broadcastQueueUpdate()
end

function MatchmakingService.getSnapshot(player)
	return buildPlayerSnapshot(player)
end

function MatchmakingService.cleanupPlayer(player)
	removeFromQueue(player)
end

return MatchmakingService
