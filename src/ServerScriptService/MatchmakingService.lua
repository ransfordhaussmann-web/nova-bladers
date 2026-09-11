local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTimers = {}
local arenaBusy = false
local remotes = nil
local onMatchReady = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countValid(queue)
	local n = 0
	for _, player in queue do
		if player.Parent then
			n += 1
		end
	end
	return n
end

local function getValidPlayers(queue, maxCount)
	local list = {}
	for _, player in queue do
		if player.Parent and #list < maxCount then
			table.insert(list, player)
		end
	end
	return list
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local cleaned = {}
	for _, player in queue do
		if player.Parent then
			table.insert(cleaned, player)
		else
			playerMode[player] = nil
		end
	end
	queues[modeId] = cleaned
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer and timer.thread then
		task.cancel(timer.thread)
		fillTimers[modeId] = nil
	end
end

local function buildUpdate(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return { inQueue = false }
	end

	pruneQueue(modeId)
	local queue = queues[modeId]
	local count = countValid(queue)
	local position = 1
	for i, queued in queue do
		if queued == player then
			position = i
			break
		end
	end

	local status = "waiting"
	local secondsLeft = nil
	local timer = fillTimers[modeId]

	if arenaBusy and count >= mode.minPlayers then
		status = "pending"
	elseif count >= mode.maxPlayers then
		status = "starting"
	elseif count >= mode.minPlayers then
		if mode.fillTimeout > 0 and timer then
			status = "filling"
			secondsLeft = math.max(0, math.ceil(timer.deadline - os.clock()))
		elseif mode.fillTimeout == 0 then
			status = "starting"
		else
			status = "waiting"
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		secondsLeft = secondsLeft,
		queuePosition = position,
	}
end

local function broadcastQueueUpdates(modeId)
	if not remotes then
		return
	end
	pruneQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildUpdate(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueueUpdates(modeId)
	end
end

local function removeFromAllQueues(player)
	for modeId in MatchmakingConfig.MODES do
		local queue = queues[modeId]
		for i = #queue, 1, -1 do
			if queue[i] == player then
				table.remove(queue, i)
				if countValid(queue) < getMode(modeId).minPlayers then
					clearFillTimer(modeId)
				end
			end
		end
	end
	playerMode[player] = nil
end

local function tryStartMode(modeId)
	if arenaBusy then
		broadcastQueueUpdates(modeId)
		return false
	end

	local mode = getMode(modeId)
	pruneQueue(modeId)
	local count = countValid(queues[modeId])
	if count < mode.minPlayers then
		return false
	end

	local players = takePlayersForMatch(modeId)
	if players and onMatchReady then
		arenaBusy = true
		onMatchReady(modeId, players)
		return true
	end
	return false
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 then
		return
	end
	if fillTimers[modeId] then
		return
	end

	local deadline = os.clock() + mode.fillTimeout
	fillTimers[modeId] = {
		deadline = deadline,
		thread = task.delay(mode.fillTimeout, function()
			fillTimers[modeId] = nil
			tryStartMode(modeId)
		end),
	}
end

local function takePlayersForMatch(modeId)
	local mode = getMode(modeId)
	pruneQueue(modeId)
	local players = getValidPlayers(queues[modeId], mode.maxPlayers)
	if #players < mode.minPlayers then
		return nil
	end

	queues[modeId] = {}
	clearFillTimer(modeId)
	for _, player in players do
		playerMode[player] = nil
		if remotes then
			remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
	return players
end

function MatchmakingService.init(remotesFolder, matchReadyCallback)
	remotes = remotesFolder
	onMatchReady = matchReadyCallback
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		MatchmakingService.processQueues()
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		if remotes then
			remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
		return
	end

	removeFromAllQueues(player)
	if remotes then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false
	end

	removeFromAllQueues(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	pruneQueue(modeId)
	local count = countValid(queues[modeId])
	if count >= mode.minPlayers and count < mode.maxPlayers and mode.fillTimeout > 0 then
		startFillTimer(modeId)
	end

	broadcastQueueUpdates(modeId)
	MatchmakingService.processQueues()
	return true
end

function MatchmakingService.processQueues()
	if arenaBusy then
		broadcastAllQueues()
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		local mode = getMode(modeId)
		pruneQueue(modeId)
		local count = countValid(queues[modeId])
		if count < mode.minPlayers then
			continue
		end

		if count >= mode.maxPlayers or mode.fillTimeout == 0 then
			if tryStartMode(modeId) then
				return
			end
		elseif not fillTimers[modeId] then
			startFillTimer(modeId)
		end
	end

	broadcastAllQueues()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromAllQueues(player)
end

return MatchmakingService
