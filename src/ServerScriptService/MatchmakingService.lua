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
local queueStartedAt = {}
local fillTimers = {}
local onMatchReady = nil
local onQueueChanged = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function copyPlayerList(modeId)
	local list = {}
	for _, entry in queues[modeId] do
		if entry.player.Parent then
			table.insert(list, entry.player)
		end
	end
	return list
end

local function buildQueuePayload(modeId)
	local config = getModeConfig(modeId)
	local entries = queues[modeId]
	local names = {}
	for _, entry in entries do
		if entry.player.Parent then
			table.insert(names, entry.player.DisplayName)
		end
	end

	local count = #names
	local status = "waiting"
	if count >= config.minPlayers and MatchStateService.isArenaBusy() then
		status = "pending"
	elseif count >= config.maxPlayers then
		status = "full"
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		count = count,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		playerNames = names,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueue(modeId)
	if not onQueueChanged then
		return
	end

	local payload = buildQueuePayload(modeId)
	for _, entry in queues[modeId] do
		local player = entry.player
		if player.Parent then
			onQueueChanged(player, {
				inQueue = true,
				position = entry.position,
				queue = payload,
			})
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function notifyLeft(player)
	if onQueueChanged then
		onQueueChanged(player, { inQueue = false })
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, entry in queue do
		if entry.player == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue == 0 then
		queueStartedAt[modeId] = nil
		clearFillTimer(modeId)
	else
		for i, entry in queue do
			entry.position = i
		end
		broadcastQueue(modeId)
	end

	notifyLeft(player)
end

local function scheduleFillTimeout(modeId)
	local config = getModeConfig(modeId)
	if config.fillTimeout <= 0 then
		return
	end
	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(config.fillTimeout, function()
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function canStartMatch(modeId)
	local config = getModeConfig(modeId)
	local count = #queues[modeId]
	if count < config.minPlayers then
		return false
	end
	if count >= config.maxPlayers then
		return true
	end
	if config.fillTimeout <= 0 then
		return count >= config.minPlayers
	end
	local startedAt = queueStartedAt[modeId]
	if not startedAt then
		return false
	end
	return os.clock() - startedAt >= config.fillTimeout
end

function MatchmakingService.tryStartMatch(modeId)
	if not isValidMode(modeId) then
		return false
	end
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end
	if not canStartMatch(modeId) then
		return false
	end

	local config = getModeConfig(modeId)
	local playerList = copyPlayerList(modeId)
	if #playerList < config.minPlayers then
		return false
	end

	local matchPlayers = {}
	for i = 1, math.min(#playerList, config.maxPlayers) do
		table.insert(matchPlayers, playerList[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	clearFillTimer(modeId)
	queueStartedAt[modeId] = nil

	MatchStateService.setArenaBusy(true)
	if onMatchReady then
		onMatchReady({
			players = matchPlayers,
			mode = modeId,
		})
	end

	broadcastAllQueues()
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end
	if MatchStateService.isArenaBusy() and #queues[modeId] == 0 and getModeConfig(modeId).minPlayers == 1 then
		-- Solo training can queue while arena is busy; will show pending.
	end

	local config = getModeConfig(modeId)
	if #queues[modeId] >= config.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queues[modeId], {
		player = player,
		position = #queues[modeId] + 1,
		joinedAt = os.clock(),
	})
	playerQueue[player] = modeId

	if not queueStartedAt[modeId] then
		queueStartedAt[modeId] = os.clock()
	end

	scheduleFillTimeout(modeId)
	broadcastQueue(modeId)

	if canStartMatch(modeId) and not MatchStateService.isArenaBusy() then
		MatchmakingService.tryStartMatch(modeId)
	elseif MatchStateService.isArenaBusy() and #queues[modeId] >= config.minPlayers then
		broadcastQueue(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	return true
end

function MatchmakingService.getPlayerQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end
	for _, entry in queues[modeId] do
		if entry.player == player then
			return {
				modeId = modeId,
				position = entry.position,
				queue = buildQueuePayload(modeId),
			}
		end
	end
	return nil
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	broadcastAllQueues()

	for modeId in queues do
		if #queues[modeId] > 0 then
			if not queueStartedAt[modeId] then
				queueStartedAt[modeId] = os.clock()
			end
			scheduleFillTimeout(modeId)
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.setHandlers(handlers)
	onMatchReady = handlers.onMatchReady
	onQueueChanged = handlers.onQueueChanged
end

function MatchmakingService.cleanupPlayer(player)
	removeFromQueue(player)
end

function MatchmakingService.pruneDisconnected()
	for modeId, queue in queues do
		for i = #queue, 1, -1 do
			local entry = queue[i]
			if not entry.player.Parent then
				playerQueue[entry.player] = nil
				table.remove(queue, i)
			end
		end
		if #queue == 0 then
			queueStartedAt[modeId] = nil
			clearFillTimer(modeId)
		else
			for i, entry in queue do
				entry.position = i
			end
			broadcastQueue(modeId)
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.cleanupPlayer(player)
end)

return MatchmakingService
