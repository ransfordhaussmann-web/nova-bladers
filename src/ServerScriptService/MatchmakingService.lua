local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady
local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil
local onPlayersEnterMatch

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if fillTimers[entry.modeId] and #queue < MatchModes.get(entry.modeId).minPlayers then
		fillTimers[entry.modeId] = nil
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local fillRemaining = nil
	local fillStarted = fillTimers[entry.modeId]
	if fillStarted and mode.fillTimeout then
		fillRemaining = math.max(0, math.ceil(mode.fillTimeout - (os.clock() - fillStarted)))
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		queued = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		pendingArena = MatchStateService.isBusy(),
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates()
	for player, _ in playerQueue do
		broadcastQueueUpdate(player)
	end
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

local function startMatch(modeId, players)
	if #players == 0 or MatchStateService.isBusy() then
		return
	end

	MatchStateService.setBusy()
	pendingMatch = nil

	if onPlayersEnterMatch then
		onPlayersEnterMatch(players, modeId)
	end

	MatchReady:Fire(modeId, players)
	broadcastQueueUpdates()
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		pendingMatch = { modeId = modeId }
		broadcastQueueUpdates()
		return
	end

	if #queue >= mode.maxPlayers then
		startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		return
	end

	if mode.fillTimeout then
		if not fillTimers[modeId] then
			fillTimers[modeId] = os.clock()
		end
		local elapsed = os.clock() - fillTimers[modeId]
		if elapsed >= mode.fillTimeout then
			startMatch(modeId, popPlayers(modeId, #queue))
		end
		return
	end

	startMatch(modeId, popPlayers(modeId, mode.minPlayers))
end

local function evaluateQueues()
	for _, mode in MatchModes.all() do
		tryStartMode(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId, joinedAt = os.clock() }
	broadcastQueueUpdate(player)
	broadcastQueueUpdates()
	evaluateQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	broadcastQueueUpdate(player)
	broadcastQueueUpdates()
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.onArenaFree()
	if pendingMatch then
		local modeId = pendingMatch.modeId
		pendingMatch = nil
		tryStartMode(modeId)
	else
		evaluateQueues()
	end
end

function MatchmakingService.init(options)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	onPlayersEnterMatch = options and options.onPlayersEnterMatch

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

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
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			for modeId, startedAt in fillTimers do
				local mode = MatchModes.get(modeId)
				if mode and mode.fillTimeout and os.clock() - startedAt >= mode.fillTimeout then
					tryStartMode(modeId)
				end
			end
			if pendingMatch and not MatchStateService.isBusy() then
				MatchmakingService.onArenaFree()
			end
		end
	end)
end

return MatchmakingService
