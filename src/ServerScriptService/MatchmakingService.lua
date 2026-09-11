local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local arenaBusy = false
local fillTimers = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	local mode = getModeConfig(entry.modeId)
	if fillTimers[entry.modeId] and #queues[entry.modeId] < mode.minPlayers then
		task.cancel(fillTimers[entry.modeId])
		fillTimers[entry.modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = MatchState.QueueStatus.Waiting
	if arenaBusy then
		status = MatchState.QueueStatus.Pending
	elseif mode.maxPlayers > 0 and #queue >= mode.maxPlayers then
		status = MatchState.QueueStatus.Ready
	elseif modeId == "training" and #queue >= 1 then
		status = MatchState.QueueStatus.Ready
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}
	for i = 1, count do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	arenaBusy = true
	broadcastAllQueues()

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = matchPlayers,
	})
end

local function scheduleFillTimer(modeId)
	local mode = getModeConfig(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if arenaBusy and playerQueue[player] and playerQueue[player].modeId == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		return false, "arena_busy"
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId }

	local mode = getModeConfig(modeId)
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)

	if modeId == "training" then
		tryStartMatch(modeId)
	elseif #queues[modeId] >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #queues[modeId] >= mode.minPlayers then
		scheduleFillTimer(modeId)
	elseif modeId == "pvp" and #queues[modeId] >= mode.minPlayers then
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	broadcastAllQueues()

	for modeId in queues do
		local mode = getModeConfig(modeId)
		local queue = queues[modeId]
		if #queue >= mode.minPlayers then
			if mode.fillTimeout > 0 and #queue < mode.maxPlayers then
				scheduleFillTimer(modeId)
			else
				tryStartMatch(modeId)
			end
		end
	end
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
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

function MatchmakingService.init()
	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerQueue[player] then
			local modeId = playerQueue[player].modeId
			removeFromQueue(player)
			broadcastQueueUpdate(modeId)
		end
	end)
end

return MatchmakingService
