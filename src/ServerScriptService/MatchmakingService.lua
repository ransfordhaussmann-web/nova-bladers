local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}

for modeId in pairs(MatchModes) do
	queues[modeId] = {
		players = {},
		waitingSince = nil,
	}
end

local function buildPayload(modeId, player)
	local queue = queues[modeId]
	local mode = MatchModes[modeId]
	local count = #queue.players
	local waitingSeconds = nil

	if queue.waitingSince and count >= mode.minPlayers then
		waitingSeconds = math.floor(os.clock() - queue.waitingSince)
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		waitingSeconds = waitingSeconds,
		fillTimeout = mode.fillTimeout,
		arenaBusy = MatchStateService.isArenaBusy(),
		position = player and table.find(queue.players, player) or nil,
	}
end

local function buildIdlePayload()
	return {
		inQueue = false,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueue(modeId)
	local payload = buildPayload(modeId)
	for _, queuedPlayer in queues[modeId].players do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end

	local mode = MatchModes[modeId]
	if #queue.players < mode.minPlayers then
		queue.waitingSince = nil
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildIdlePayload())
	end
	broadcastQueue(modeId)
end

local function shouldStartMatch(modeId, count)
	local mode = MatchModes[modeId]
	local queue = queues[modeId]

	if count < mode.minPlayers then
		return false
	end

	if modeId == "training" then
		return count >= 1
	end

	if modeId == "pvp" then
		return count >= 2
	end

	if count >= mode.maxPlayers then
		return true
	end

	if queue.waitingSince and mode.fillTimeout > 0 then
		return os.clock() - queue.waitingSince >= mode.fillTimeout
	end

	return false
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end

	local queue = queues[modeId]
	local mode = MatchModes[modeId]
	local count = #queue.players

	if not shouldStartMatch(modeId, count) then
		return false
	end

	local matchPlayers = {}
	local takeCount = math.min(count, mode.maxPlayers)
	for index = 1, takeCount do
		table.insert(matchPlayers, queue.players[index])
	end

	queue.players = {}
	queue.waitingSince = nil

	for _, matchPlayer in matchPlayers do
		playerQueue[matchPlayer] = nil
		if matchPlayer.Parent then
			Remotes.QueueUpdate:FireClient(matchPlayer, {
				inQueue = false,
				matchFound = true,
				modeId = modeId,
				modeLabel = mode.label,
			})
			HubService.leaveHubForArena(matchPlayer)
		end
	end

	Bindables.MatchReady:Fire(matchPlayers, modeId)
	return true
end

local function tryStartAllQueues()
	for modeId in pairs(MatchModes) do
		tryStartMatch(modeId)
	end
end

local function markWaiting(modeId)
	local queue = queues[modeId]
	local mode = MatchModes[modeId]
	if #queue.players >= mode.minPlayers and not queue.waitingSince then
		queue.waitingSince = os.clock()
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes[modeId] then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerQueue[player] = modeId
	markWaiting(modeId)

	Remotes.QueueUpdate:FireClient(player, buildPayload(modeId, player))
	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getQueueCount(modeId)
	local queue = queues[modeId]
	return queue and #queue.players or 0
end

function MatchmakingService.init()
	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		tryStartAllQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.FILL_CHECK_INTERVAL)
			for modeId, queue in pairs(queues) do
				local mode = MatchModes[modeId]
				if queue.waitingSince and #queue.players >= mode.minPlayers and mode.fillTimeout > 0 then
					tryStartMatch(modeId)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			for modeId, queue in pairs(queues) do
				if #queue.players > 0 then
					broadcastQueue(modeId)
				end
			end
		end
	end)
end

return MatchmakingService
