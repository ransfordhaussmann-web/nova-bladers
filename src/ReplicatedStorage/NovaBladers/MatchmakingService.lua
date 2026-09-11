local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTokens = {}
local arenaBusy = false
local onQueueUpdate = nil
local onMatchReady = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
	fillTokens[modeId] = 0
end

local function isValidMode(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

local function getQueueCount(modeId)
	local count = 0
	for _, player in queues[modeId] do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function pruneQueue(modeId)
	local nextQueue = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(nextQueue, player)
		else
			playerMode[player] = nil
		end
	end
	queues[modeId] = nextQueue
end

local function buildPlayerUpdate(player)
	local modeId = playerMode[player]
	if not modeId then
		return {
			status = MatchState.QueueStatus.Idle,
		}
	end

	pruneQueue(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	local position = 0
	for index, queued in queue do
		if queued == player then
			position = index
			break
		end
	end

	local status = MatchState.QueueStatus.Waiting
	if arenaBusy then
		status = MatchState.QueueStatus.Pending
	end

	return {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = arenaBusy,
	}
end

local function notifyPlayer(player)
	if onQueueUpdate and player.Parent then
		onQueueUpdate(player, buildPlayerUpdate(player))
	end
end

local function notifyQueue(modeId)
	pruneQueue(modeId)
	for _, player in queues[modeId] do
		notifyPlayer(player)
	end
end

local function notifyAllQueues()
	for modeId in MatchmakingConfig.MODES do
		notifyQueue(modeId)
	end
end

local function takePlayers(modeId, count)
	pruneQueue(modeId)
	local taken = {}
	local remaining = {}

	for index, player in queues[modeId] do
		if #taken < count then
			table.insert(taken, player)
			playerMode[player] = nil
		else
			table.insert(remaining, player)
		end
	end

	queues[modeId] = remaining
	return taken
end

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	arenaBusy = true
	notifyAllQueues()

	if onMatchReady then
		onMatchReady({
			mode = modeId,
			players = players,
		})
	end
end

local function tryStartMode(modeId)
	if arenaBusy then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	pruneQueue(modeId)
	local count = #queues[modeId]
	if count < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			fillTokens[modeId] += 1
			startMatch(modeId, takePlayers(modeId, mode.maxPlayers))
			return
		end

		fillTokens[modeId] += 1
		local token = fillTokens[modeId]
		task.delay(mode.fillTimeout, function()
			if token ~= fillTokens[modeId] or arenaBusy then
				return
			end
			pruneQueue(modeId)
			if #queues[modeId] < mode.minPlayers then
				return
			end
			local playerCount = math.min(#queues[modeId], mode.maxPlayers)
			startMatch(modeId, takePlayers(modeId, playerCount))
		end)
		return
	end

	local playerCount = math.min(count, mode.maxPlayers)
	startMatch(modeId, takePlayers(modeId, playerCount))
end

local function tryStartAll()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

function MatchmakingService.configure(handlers)
	onQueueUpdate = handlers.onQueueUpdate
	onMatchReady = handlers.onMatchReady
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		tryStartAll()
	else
		notifyAllQueues()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if arenaBusy and not playerMode[player] then
		-- allow joining while busy; players wait as pending
	end

	MatchmakingService.leaveQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	notifyPlayer(player)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	pruneQueue(modeId)

	if modeId == "ffa" then
		fillTokens[modeId] += 1
	end

	notifyQueue(modeId)
end

function MatchmakingService.getPlayerUpdate(player)
	return buildPlayerUpdate(player)
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
