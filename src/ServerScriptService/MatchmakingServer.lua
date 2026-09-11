local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(ReplicatedStorage.NovaBladers.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingServer = {}

local initialized = false
local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local arenaBusy = false

local function getQueue(modeId)
	return queues[modeId]
end

local function countQueue(modeId)
	return #getQueue(modeId)
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId] = nil
	end
end

local function sendQueueUpdate(player, modeId, status, extra)
	local payload
	if modeId then
		payload = MatchmakingService.buildQueuePayload(modeId, countQueue(modeId), status, extra)
	else
		payload = MatchmakingService.buildIdlePayload()
	end
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function broadcastQueueUpdates(modeId, status)
	local extra = nil
	if fillTimers[modeId] and fillTimers[modeId].endsAt then
		extra = {
			fillSecondsLeft = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock())),
		}
	end

	for _, player in getQueue(modeId) do
		if player.Parent then
			sendQueueUpdate(player, modeId, status, extra)
		end
	end
end

local function getQueueStatus(modeId)
	if arenaBusy then
		return "pending"
	end

	local mode = MatchmakingConfig.MODES[modeId]
	local size = countQueue(modeId)
	if mode.fillTimeout > 0 and size >= mode.minPlayers and fillTimers[modeId] then
		return "filling"
	end
	return "waiting"
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	fillTimers[modeId] = nil
	return picked
end

local function tryStartMode(modeId)
	if arenaBusy then
		return false
	end

	local mode = MatchmakingConfig.MODES[modeId]
	local queue = getQueue(modeId)
	local size = #queue

	if size < mode.minPlayers then
		return false
	end

	local shouldStart = false
	local playerCount = size

	if mode.fillTimeout > 0 then
		if size >= mode.maxPlayers then
			shouldStart = true
			playerCount = mode.maxPlayers
		elseif fillTimers[modeId] and os.clock() >= fillTimers[modeId].endsAt then
			shouldStart = true
			playerCount = math.min(size, mode.maxPlayers)
		end
	else
		shouldStart = size >= mode.minPlayers
		playerCount = math.min(size, mode.maxPlayers)
	end

	if not shouldStart then
		return false
	end

	local players = popPlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queue, player)
			playerQueue[player] = modeId
		end
		return false
	end

	arenaBusy = true
	broadcastQueueUpdates(modeId, "starting")
	Bindables.MatchReady:Fire(players, modeId)
	return true
end

local function tryStartAllQueues()
	for modeId in MatchmakingConfig.MODES do
		if tryStartMode(modeId) then
			return
		end
	end
end

local function ensureFillTimer(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	if mode.fillTimeout <= 0 then
		return
	end

	local size = countQueue(modeId)
	if size < mode.minPlayers then
		fillTimers[modeId] = nil
		return
	end

	if not fillTimers[modeId] then
		fillTimers[modeId] = {
			startedAt = os.clock(),
			endsAt = os.clock() + mode.fillTimeout,
		}

		task.delay(mode.fillTimeout, function()
			if fillTimers[modeId] and os.clock() >= fillTimers[modeId].endsAt then
				tryStartMode(modeId)
			end
		end)
	end
end

function MatchmakingServer.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
		return false
	end
	if playerQueue[player] then
		return false
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	ensureFillTimer(modeId)
	broadcastQueueUpdates(modeId, getQueueStatus(modeId))
	tryStartMode(modeId)
	return true
end

function MatchmakingServer.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		sendQueueUpdate(player, nil)
		return
	end

	removeFromQueue(player)
	sendQueueUpdate(player, nil)
	broadcastQueueUpdates(modeId, getQueueStatus(modeId))
end

function MatchmakingServer.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingServer.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingServer.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingServer.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingServer.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		arenaBusy = false
		for modeId in MatchmakingConfig.MODES do
			broadcastQueueUpdates(modeId, getQueueStatus(modeId))
		end
		tryStartAllQueues()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingServer.leaveQueue(player)
	end)
end

return MatchmakingServer
