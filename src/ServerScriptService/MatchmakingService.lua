local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {
			players = {},
			pending = false,
		}
	end
end

local function getValidPlayers(playerList)
	local valid = {}
	for _, player in playerList do
		if player.Parent then
			table.insert(valid, player)
		end
	end
	return valid
end

local function buildQueuePayload(modeId, player)
	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	if not queue or not mode then
		return { inQueue = false }
	end

	local count = #getValidPlayers(queue.players)
	local status = "waiting"
	if queue.pending then
		status = "pending"
	end

	local secondsLeft
	local timer = fillTimers[modeId]
	if timer and timer.endsAt then
		secondsLeft = math.max(0, math.ceil(timer.endsAt - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		needed = mode.minPlayers,
		max = mode.maxPlayers,
		status = status,
		secondsLeft = secondsLeft,
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for _, player in queue.players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer and timer.thread then
		task.cancel(timer.thread)
	end
	fillTimers[modeId] = nil
end

local function removeFromQueue(player, modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for i, p in queue.players do
		if p == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
		queue.pending = false
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	removeFromQueue(player, modeId)
	playerQueue[player] = nil
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)
end

local function takePlayers(modeId)
	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	local valid = getValidPlayers(queue.players)
	local count = math.min(#valid, mode.maxPlayers)

	local taken = {}
	for i = 1, count do
		table.insert(taken, valid[i])
	end

	for _, player in taken do
		removeFromQueue(player, modeId)
		playerQueue[player] = nil
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
	end

	clearFillTimer(modeId)
	queue.pending = false
	broadcastQueue(modeId)

	return taken
end

local function launchMatch(modeId)
	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	local valid = getValidPlayers(queue.players)

	if #valid < mode.minPlayers then
		queue.pending = false
		return
	end

	if MatchStateService.isBusy() then
		queue.pending = true
		broadcastQueue(modeId)
		return
	end

	MatchStateService.setBusy(true)

	local players = takePlayers(modeId)
	if #players < mode.minPlayers then
		MatchStateService.setBusy(false)
		return
	end

	task.delay(MatchmakingConfig.MATCH_START_DELAY, function()
		MatchReady:Fire(players)
	end)
end

local function tryLaunchMatch(modeId)
	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	local count = #getValidPlayers(queue.players)

	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		launchMatch(modeId)
		return
	end

	if mode.fillTimeout > 0 then
		if not fillTimers[modeId] then
			local endsAt = os.clock() + mode.fillTimeout
			fillTimers[modeId] = { endsAt = endsAt }
			fillTimers[modeId].thread = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				launchMatch(modeId)
			end)
		end
	else
		launchMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	MatchmakingService.leaveQueue(player)
	HubService.prepareForMatchmaking(player)

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	broadcastQueue(modeId)
	tryLaunchMatch(modeId)
end

function MatchmakingService.joinAutoQueue(player)
	local count = #Players:GetPlayers()
	local modeId = MatchModes.resolveAuto(count)
	MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

local function onArenaFree()
	for modeId, queue in queues do
		if queue.pending and #getValidPlayers(queue.players) >= MatchModes.get(modeId).minPlayers then
			launchMatch(modeId)
		end
	end
end

local function onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" and modeId ~= "" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinAutoQueue(player)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(onPlayerRemoving)
	MatchStateService.onArenaFree(onArenaFree)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastAllQueues()
		end
	end)
end

return MatchmakingService
