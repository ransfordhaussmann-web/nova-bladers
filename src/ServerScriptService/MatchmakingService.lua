local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local callbacks = {}

local function getQueueNames(modeId)
	local list = queues[modeId]
	if not list then
		return {}
	end

	local names = {}
	for _, player in list do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end
	return names
end

local function buildQueuePayload(player, modeId, extra)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = queues[modeId] or {}
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		inQueue = position > 0,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		fillRemaining = extra and extra.fillRemaining,
		pendingArena = extra and extra.pendingArena or false,
		playerNames = getQueueNames(modeId),
	}
end

local function sendQueueUpdate(player, modeId, extra)
	local payload = buildQueuePayload(player, modeId, extra)
	if payload and player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdate(modeId, extra)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for _, player in queue do
		sendQueueUpdate(player, modeId, extra)
	end
end

local function cancelFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId] = nil
	end
end

local function clearPlayerFromQueues(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil
	cancelFillTimer(modeId)
	broadcastQueueUpdate(modeId)
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
	fillTimers[modeId] = token
	local deadline = os.clock() + mode.fillTimeout

	task.spawn(function()
		while fillTimers[modeId] == token do
			local remaining = deadline - os.clock()
			if remaining <= 0 then
				fillTimers[modeId] = nil
				MatchmakingService.tryStartMatch(modeId)
				return
			end

			broadcastQueueUpdate(modeId, { fillRemaining = math.ceil(remaining) })
			task.wait(MatchmakingConfig.FILL_TICK_INTERVAL)
		end
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue or #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId, { pendingArena = true })
		return
	end

	if mode.fillTimeout and #queue < mode.maxPlayers and fillTimers[modeId] then
		return
	end

	local take = math.min(#queue, mode.maxPlayers)
	local matched = {}
	for i = 1, take do
		table.insert(matched, queue[i])
	end

	for i = 1, take do
		local player = queue[1]
		table.remove(queue, 1)
		playerQueue[player] = nil
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	cancelFillTimer(modeId)
	MatchStateService.setArenaBusy(true)

	for _, player in matched do
		if callbacks.onMatchStarting then
			callbacks.onMatchStarting(player)
		end
	end

	Bindables.MatchReady:Fire(matched)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId, joinedAt = os.clock() }
	broadcastQueueUpdate(modeId)

	local queue = queues[modeId]
	if #queue >= mode.maxPlayers then
		cancelFillTimer(modeId)
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if #queue >= mode.minPlayers then
		if mode.fillTimeout then
			startFillTimer(modeId)
		else
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	clearPlayerFromQueues(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)

	for modeId, _ in queues do
		local queue = queues[modeId]
		if queue and #queue > 0 then
			local mode = MatchModes.get(modeId)
			if mode and #queue >= mode.minPlayers then
				if mode.fillTimeout and not fillTimers[modeId] then
					startFillTimer(modeId)
				else
					MatchmakingService.tryStartMatch(modeId)
				end
			else
				broadcastQueueUpdate(modeId)
			end
		end
	end
end

function MatchmakingService.init(hubCallbacks)
	callbacks = hubCallbacks or {}
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)
	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
