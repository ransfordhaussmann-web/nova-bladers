local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local pendingModes = {}
local arenaBusy = false
local started = false

local function getQueue(modeId)
	return queues[modeId] or {}
end

local function countQueue(modeId)
	return #getQueue(modeId)
end

local function isValidMode(modeId)
	return MatchModes.get(modeId) ~= nil
end

local function canStart(modeId, count)
	local mode = MatchModes.get(modeId)
	if not mode or count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.instantStart and count >= mode.minPlayers then
		return true
	end
	if mode.fillTimeout and fillTimers[modeId] then
		return true
	end
	return false
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local count = countQueue(modeId)
	local ready = canStart(modeId, count)
	local status = "waiting"

	if ready then
		status = arenaBusy and "pending" or "ready"
	elseif mode.fillTimeout and count >= mode.minPlayers then
		status = "filling"
	end

	local fillSecondsLeft
	local timer = fillTimers[modeId]
	if timer then
		fillSecondsLeft = math.max(0, math.ceil(timer.endsAt - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
end

local function broadcastQueueUpdate(modeId)
	for _, player in getQueue(modeId) do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	local token = {}
	fillTimers[modeId] = {
		token = token,
		endsAt = os.clock() + mode.fillTimeout,
	}
	broadcastQueueUpdate(modeId)

	task.delay(mode.fillTimeout, function()
		local timer = fillTimers[modeId]
		if not timer or timer.token ~= token then
			return
		end
		clearFillTimer(modeId)
		MatchmakingService.tryStart(modeId)
	end)
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
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

	playerQueue[player] = nil
	pendingModes[modeId] = nil

	if countQueue(modeId) < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
end

local function dequeuePlayers(modeId, amount)
	local queue = queues[modeId]
	local players = {}
	local take = math.min(amount, #queue)

	for index = 1, take do
		local player = queue[index]
		table.insert(players, player)
		playerQueue[player] = nil
	end

	for index = 1, take do
		table.remove(queue, 1)
	end

	clearFillTimer(modeId)
	pendingModes[modeId] = nil
	return players
end

local function launchMatch(modeId, players)
	arenaBusy = true

	for _, player in players do
		if player.Parent then
			HubService.leaveHubForArena(player)
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end

	Bindables.MatchReady:Fire(players, modeId)
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		for modeId in pairs(queues) do
			MatchmakingService.tryStart(modeId)
		end
	end
end

function MatchmakingService.getQueuedMode(player)
	return playerQueue[player]
end

function MatchmakingService.leaveQueue(player)
	removePlayerFromQueue(player)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	if playerQueue[player] then
		removePlayerFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	MatchmakingService.tryStart(modeId)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.joinQuickMatch(player)
	local modeId = MatchModes.getQuickMatchMode(#Players:GetPlayers())
	MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.tryStart(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = countQueue(modeId)
	if count < mode.minPlayers then
		broadcastQueueUpdate(modeId)
		return
	end

	if count >= mode.maxPlayers then
		if arenaBusy then
			pendingModes[modeId] = true
			broadcastQueueUpdate(modeId)
			return
		end

		local players = dequeuePlayers(modeId, mode.maxPlayers)
		launchMatch(modeId, players)
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.instantStart and count >= mode.minPlayers then
		if arenaBusy then
			pendingModes[modeId] = true
			broadcastQueueUpdate(modeId)
			return
		end

		local players = dequeuePlayers(modeId, count)
		launchMatch(modeId, players)
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.fillTimeout then
		if not fillTimers[modeId] then
			startFillTimer(modeId)
		end

		if arenaBusy then
			if canStart(modeId, count) then
				pendingModes[modeId] = true
			end
			broadcastQueueUpdate(modeId)
			return
		end

		if fillTimers[modeId] and os.clock() >= fillTimers[modeId].endsAt then
			local players = dequeuePlayers(modeId, count)
			launchMatch(modeId, players)
			broadcastQueueUpdate(modeId)
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" and isValidMode(modeId) then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinQuickMatch(player)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for modeId in pairs(fillTimers) do
				broadcastQueueUpdate(modeId)
			end
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
