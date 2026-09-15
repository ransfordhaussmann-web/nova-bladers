local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function countQueue(modeId)
	return #getQueue(modeId)
end

local function isPlayerValid(player)
	return player and player.Parent == Players
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local cleaned = {}
	for _, player in queue do
		if isPlayerValid(player) then
			table.insert(cleaned, player)
		else
			playerQueue[player] = nil
		end
	end
	queues[modeId] = cleaned
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	pruneQueue(modeId)
	local count = countQueue(modeId)
	local pending = MatchStateService.isActive()
	local status = "waiting"

	if pending then
		status = "pending"
	elseif count >= mode.minPlayers then
		if modeId == "ffa" and count < mode.maxPlayers then
			local timer = fillTimers[modeId]
			if timer and timer.expiresAt then
				status = "filling"
			else
				status = "ready"
			end
		else
			status = "ready"
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		pending = pending,
		inQueue = player ~= nil,
		fillSecondsLeft = (function()
			local timer = fillTimers[modeId]
			if timer and timer.expiresAt then
				return math.max(0, math.ceil(timer.expiresAt - os.clock()))
			end
			return nil
		end)(),
	}
end

local function broadcastQueueUpdate(modeId)
	pruneQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if isPlayerValid(player) then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = {
		expiresAt = os.clock() + mode.fillTimeout,
	}

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

local function removeFromQueue(player, modeId)
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if playerQueue[player] == modeId then
		playerQueue[player] = nil
	end

	if countQueue(modeId) < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end
	removeFromQueue(player, modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not isPlayerValid(player) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	pruneQueue(modeId)
	local queue = getQueue(modeId)
	if countQueue(modeId) >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	local payload = buildQueuePayload(modeId, player)
	Remotes.QueueUpdate:FireClient(player, payload)
	broadcastQueueUpdate(modeId)

	if countQueue(modeId) >= mode.minPlayers then
		if modeId == "ffa" and countQueue(modeId) < mode.maxPlayers then
			startFillTimer(modeId)
		else
			MatchmakingService.tryStartMatch(modeId)
		end
	end

	return true
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isActive() then
		broadcastAllQueues()
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	pruneQueue(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	if count < mode.minPlayers then
		return false
	end

	local players = {}
	for i = 1, math.min(count, mode.maxPlayers) do
		table.insert(players, queue[i])
	end

	if #players == 0 then
		return false
	end

	clearFillTimer(modeId)
	queues[modeId] = {}

	for _, player in players do
		playerQueue[player] = nil
	end

	broadcastQueueUpdate(modeId)
	MatchReady:Fire(modeId, players)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerQueue[player]
		if modeId then
			removeFromQueue(player, modeId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			if MatchStateService.isActive() then
				broadcastAllQueues()
			else
				for modeId, mode in MatchModes.all() do
					pruneQueue(modeId)
					local count = countQueue(modeId)
					if count >= mode.minPlayers then
						local canStart = modeId ~= "ffa"
							or count >= mode.maxPlayers
							or (fillTimers[modeId] and os.clock() >= fillTimers[modeId].expiresAt)
						if canStart then
							MatchmakingService.tryStartMatch(modeId)
						end
					end
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
