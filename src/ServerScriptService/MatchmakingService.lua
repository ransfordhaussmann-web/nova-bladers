local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local deps = nil
local Remotes = nil
local MatchReady = nil

local function initQueues()
	for modeId in MatchModes.getAll() do
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
end

local function countQueue(modeId)
	return #queues[modeId].players
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	for i, p in queue.players do
		if p == player then
			table.remove(queue.players, i)
			break
		end
	end

	if countQueue(entry.modeId) < MatchModes.get(entry.modeId).minPlayers then
		queue.fillDeadline = nil
	end

	playerEntry[player] = nil
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local inQueue = playerEntry[player] ~= nil
	local pendingArena = inQueue and MatchStateService.isBusy()

	local fillSecondsLeft = nil
	if modeId == "ffa" and queue.fillDeadline then
		fillSecondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = inQueue,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = countQueue(modeId),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pendingArena = pendingArena,
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function sendQueueUpdate(player)
	local entry = playerEntry[player]
	if not entry then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, entry.modeId))
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId].players do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, count do
		local player = table.remove(queue.players, 1)
		if player then
			playerEntry[player] = nil
			if player.Parent then
				table.insert(picked, player)
			end
		end
	end
	queue.fillDeadline = nil
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if deps.onMatchFormed then
		deps.onMatchFormed(playerList, modeId)
	end

	MatchReady:Fire(playerList, modeId)
	broadcastQueue(modeId)
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local size = countQueue(modeId)

	if size < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if size >= mode.maxPlayers then
			launchMatch(modeId, popPlayers(modeId, mode.maxPlayers))
			return
		end

		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
		end

		if os.clock() >= queue.fillDeadline then
			launchMatch(modeId, popPlayers(modeId, size))
		end
		return
	end

	launchMatch(modeId, popPlayers(modeId, mode.maxPlayers))
end

local function processQueues()
	for modeId in MatchModes.getAll() do
		tryStartMatch(modeId)
	end

	for _, player in Players:GetPlayers() do
		if playerEntry[player] then
			sendQueueUpdate(player)
		end
	end
end

local function onArenaFreed()
	processQueues()
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return
	end
	if playerEntry[player] and playerEntry[player].modeId == modeId then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId].players, player)
	playerEntry[player] = { modeId = modeId }

	sendQueueUpdate(player)
	broadcastQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local modeId = playerEntry[player].modeId
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)
end

function MatchmakingService.getQueueSize(modeId)
	return countQueue(modeId)
end

function MatchmakingService.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.start(options)
	deps = options
	Remotes, localBindables = RemotesSetup.ensure()
	MatchReady = localBindables.MatchReady

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	task.spawn(function()
		while true do
			processQueues()
			task.wait(MatchmakingConfig.QUEUE_TICK)
		end
	end)

	MatchStateService.onFreed = onArenaFreed
end

return MatchmakingService
