local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local arenaBusy = false
local callbacks = {
	onQueueUpdate = nil,
	onMatchReady = nil,
}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {
		players = {},
		fillDeadline = nil,
	}
end

local function getMode(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players < getMode(modeId).minPlayers then
		queue.fillDeadline = nil
	end

	playerMode[player] = nil
end

local function getQueueStatus(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = #queue.players
	local status = "waiting"

	if arenaBusy and count > 0 then
		status = "pending"
	elseif modeId == "ffa" and count >= mode.minPlayers then
		if count >= mode.maxPlayers then
			status = "starting"
		elseif queue.fillDeadline and os.clock() >= queue.fillDeadline then
			status = "starting"
		else
			status = "filling"
		end
	elseif count >= mode.minPlayers then
		status = "starting"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = queue.fillDeadline
			and math.max(0, math.ceil(queue.fillDeadline - os.clock()))
			or nil,
	}
end

local function buildPlayerUpdate(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local status = getQueueStatus(modeId)
	local memberNames = {}
	for _, queuedPlayer in queues[modeId].players do
		if queuedPlayer.Parent then
			table.insert(memberNames, queuedPlayer.DisplayName)
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = status.modeLabel,
		players = status.players,
		needed = status.needed,
		maxPlayers = status.maxPlayers,
		status = status.status,
		fillSecondsLeft = status.fillSecondsLeft,
		memberNames = memberNames,
	}
end

local function notifyPlayer(player)
	if callbacks.onQueueUpdate and player.Parent then
		callbacks.onQueueUpdate(player, buildPlayerUpdate(player))
	end
end

local function notifyAllQueued()
	for player in playerMode do
		notifyPlayer(player)
	end
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for i = 1, math.min(count, #queue.players) do
		local player = queue.players[1]
		table.remove(queue.players, 1)
		playerMode[player] = nil
		table.insert(taken, player)
	end
	queue.fillDeadline = nil
	return taken
end

local function tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	if count < mode.minPlayers then
		return
	end

	local shouldStart = false
	local playerCount = count

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			shouldStart = true
			playerCount = mode.maxPlayers
		elseif queue.fillDeadline and os.clock() >= queue.fillDeadline then
			shouldStart = true
			playerCount = count
		elseif not queue.fillDeadline then
			queue.fillDeadline = os.clock() + mode.fillTimeout
			notifyAllQueued()
			return
		else
			return
		end
	else
		shouldStart = count >= mode.minPlayers
		playerCount = mode.minPlayers
	end

	if not shouldStart then
		return
	end

	local matchPlayers = takePlayers(modeId, playerCount)
	if #matchPlayers == 0 then
		return
	end

	arenaBusy = true
	notifyAllQueued()

	if callbacks.onMatchReady then
		callbacks.onMatchReady(matchPlayers, modeId)
	end
end

local function evaluateQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.registerHandlers(handlers)
	callbacks.onQueueUpdate = handlers.onQueueUpdate
	callbacks.onMatchReady = handlers.onMatchReady
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	notifyAllQueued()
	if not busy then
		evaluateQueues()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		notifyPlayer(player)
		return false
	end

	if playerMode[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId].players, player)
	playerMode[player] = modeId
	notifyPlayer(player)
	evaluateQueues()
	return true
end

function MatchmakingService.joinRecommendedQueue(player)
	local count = #Players:GetPlayers()
	local modeId = MatchmakingConfig.getRecommendedMode(count)
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		notifyPlayer(player)
		return false
	end

	removeFromQueue(player)
	notifyPlayer(player)
	notifyAllQueued()
	return true
end

function MatchmakingService.getPlayerUpdate(player)
	return buildPlayerUpdate(player)
end

function MatchmakingService.clearPlayer(player)
	removeFromQueue(player)
end

function MatchmakingService.getQueueCounts()
	local counts = {}
	for modeId in MatchmakingConfig.MODES do
		counts[modeId] = #queues[modeId].players
	end
	return counts
end

function MatchmakingService.tick()
	evaluateQueues()
	notifyAllQueued()
end

return MatchmakingService
