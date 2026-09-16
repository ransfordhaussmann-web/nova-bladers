local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false
local onMatchReady

local function ensureRemotes()
	if not Remotes then
		Remotes = RemotesSetup.ensure()
	end
	return Remotes
end

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function getQueueNames(modeId)
	local names = {}
	for _, queuedPlayer in getQueue(modeId) do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end
	return names
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local pending = MatchStateService.isArenaBusy()

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = getQueueNames(modeId),
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		fillTimeout = mode.fillTimeout,
	}
end

local function broadcastQueueUpdate(modeId)
	local payloadBase = {
		modeId = modeId,
		players = getQueueNames(modeId),
		count = #getQueue(modeId),
		minPlayers = MatchModes.get(modeId).minPlayers,
		maxPlayers = MatchModes.get(modeId).maxPlayers,
		pending = MatchStateService.isArenaBusy(),
		fillTimeout = MatchModes.get(modeId).fillTimeout,
		modeLabel = MatchModes.get(modeId).label,
	}

	for _, queuedPlayer in getQueue(modeId) do
		if queuedPlayer.Parent then
			ensureRemotes().QueueUpdate:FireClient(queuedPlayer, payloadBase)
		end
	end
end

local function popQueuePlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}

	for i = 1, math.min(count, #queue) do
		local player = queue[1]
		table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerQueue[player] = nil
			ensureRemotes().QueueUpdate:FireClient(player, nil)
		end
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	broadcastQueueUpdate(modeId)
	return picked
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	local count = math.min(#queue, mode.maxPlayers)
	local players = popQueuePlayers(modeId, count)

	if #players == 0 then
		return
	end

	if onMatchReady then
		onMatchReady(players, modeId)
	end
end

local function scheduleFillStart(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "unknown_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	if MatchStateService.isArenaBusy() then
		table.insert(getQueue(modeId), player)
		playerQueue[player] = modeId
		ensureRemotes().QueueUpdate:FireClient(player, buildQueuePayload(player))
		return true, "pending"
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)

	if #getQueue(modeId) >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #getQueue(modeId) >= mode.minPlayers then
		if mode.fillTimeout then
			scheduleFillStart(modeId)
		else
			tryStartMatch(modeId)
		end
	end

	return true, "queued"
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	ensureRemotes().QueueUpdate:FireClient(player, nil)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	for modeId in queues do
		local mode = MatchModes.get(modeId)
		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers then
			tryStartMatch(modeId)
		else
			broadcastQueueUpdate(modeId)
		end
	end
end

function MatchmakingService.setMatchReadyHandler(handler)
	onMatchReady = handler
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	local remotes = ensureRemotes()

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId in queues do
				if #getQueue(modeId) > 0 then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
