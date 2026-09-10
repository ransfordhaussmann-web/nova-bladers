local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local queues = {}
for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {
		players = {},
		fillDeadline = nil,
		status = "waiting",
		fillToken = 0,
	}
end

local playerQueue = {}

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local names = {}
	for _, p in queue.players do
		if p.Parent then
			table.insert(names, p.Name)
		end
	end
	return {
		mode = modeId,
		label = mode.label,
		count = #names,
		min = mode.minPlayers,
		max = mode.maxPlayers,
		status = queue.status,
		players = names,
		fillTimeout = mode.fillTimeout,
		secondsLeft = nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId)
	if payload.fillTimeout and queues[modeId].fillDeadline then
		payload.secondsLeft = math.max(0, math.ceil(queues[modeId].fillDeadline - os.clock()))
	end
	for _, p in queues[modeId].players do
		if p.Parent then
			Remotes.QueueUpdate:FireClient(p, payload)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, p in queue.players do
		if p == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue.players < getMode(modeId).minPlayers then
		queue.fillDeadline = nil
		queue.fillToken += 1
	end

	if #queue.players == 0 then
		queue.status = "waiting"
		queue.fillDeadline = nil
	else
		queue.status = "waiting"
		broadcastQueueUpdate(modeId)
	end
end

local function canStartMatch(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "ffa" and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true
	end
	return modeId ~= "ffa" and count >= mode.minPlayers
end

local function popMatchPlayers(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue.players, mode.maxPlayers)
	local matchPlayers = {}
	for i = 1, count do
		table.insert(matchPlayers, queue.players[i])
	end
	for i = 1, count do
		table.remove(queue.players, 1)
	end
	for _, p in matchPlayers do
		playerQueue[p] = nil
	end
	queue.fillDeadline = nil
	queue.fillToken += 1
	queue.status = "waiting"
	return matchPlayers
end

local function tryStartQueue(modeId)
	local queue = queues[modeId]
	if #queue.players == 0 then
		return
	end
	if not canStartMatch(modeId) then
		return
	end

	if MatchmakingService.isArenaBusy() then
		queue.status = "pending"
		broadcastQueueUpdate(modeId)
		return
	end

	local matchPlayers = popMatchPlayers(modeId)
	queue.status = "starting"
	broadcastQueueUpdate(modeId)

	MatchmakingService.setArenaBusy(true)
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = matchPlayers,
	})
end

local function tryStartAllQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartQueue(modeId)
	end
end

local function scheduleFfaFill(modeId)
	local mode = getMode(modeId)
	if not mode.fillTimeout then
		return
	end

	local queue = queues[modeId]
	if #queue.players < mode.minPlayers then
		return
	end
	if queue.fillDeadline then
		return
	end

	queue.fillDeadline = os.clock() + mode.fillTimeout
	queue.fillToken += 1
	local token = queue.fillToken

	broadcastQueueUpdate(modeId)

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		tryStartQueue(modeId)
	end)
end

local function joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		removeFromQueue(player)
	end
	if #queues[modeId].players >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId
	queues[modeId].status = "waiting"

	broadcastQueueUpdate(modeId)
	scheduleFfaFill(modeId)
	tryStartQueue(modeId)
	return true
end

local function leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	local modeId = playerQueue[player]
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, {
		mode = nil,
		status = "left",
	})
	if #queues[modeId].players > 0 then
		broadcastQueueUpdate(modeId)
	end
end

local function init()
	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.setArenaBusy(false)
	end)

	MatchmakingService.onArenaFreed(tryStartAllQueues)

	print("[MatchmakingManager] Queue system ready")
end

init()

return {
	joinQueue = joinQueue,
	leaveQueue = leaveQueue,
	getPlayerMode = function(player)
		return playerQueue[player]
	end,
}
