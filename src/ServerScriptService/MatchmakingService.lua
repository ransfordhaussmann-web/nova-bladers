local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillStartedAt = {}
local pendingMatch = nil
local started = false
local tickTask = nil

local function getQueue(modeId)
	return queues[modeId]
end

local function countInQueue(modeId)
	return #getQueue(modeId)
end

local function removeFromQueue(player, modeId)
	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			return true
		end
	end
	return false
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local startedAt = fillStartedAt[modeId]
	local fillTimeout = mode.fillTimeout
	local timeLeft = nil
	if startedAt and fillTimeout then
		timeLeft = math.max(0, math.ceil(fillTimeout - (os.clock() - startedAt)))
	end

	local status = "waiting"
	if pendingMatch and pendingMatch.modeId == modeId then
		for _, p in pendingMatch.players do
			if p == player then
				status = "pending"
				break
			end
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeLeft = timeLeft,
		status = status,
	}
end

local function broadcastQueueUpdate(targetPlayer)
	if targetPlayer then
		Remotes.QueueUpdate:FireClient(targetPlayer, buildQueuePayload(targetPlayer))
		return
	end

	for queuedPlayer, _ in playerQueue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer))
		end
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player, modeId)
	playerQueue[player] = nil

	if countInQueue(modeId) == 0 then
		fillStartedAt[modeId] = nil
	end
end

local function takePlayersFromQueue(modeId, amount)
	local queue = getQueue(modeId)
	local taken = {}
	for _ = 1, math.min(amount, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end

	if countInQueue(modeId) == 0 then
		fillStartedAt[modeId] = nil
	end

	return taken
end

local function resolveModeForQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queueSize = countInQueue(modeId)

	if modeId == "ffa" and queueSize == 2 then
		return MatchModes.pvp, 2
	end

	return mode, math.min(queueSize, mode.maxPlayers)
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queueSize = countInQueue(modeId)

	if modeId == "training" then
		return queueSize >= 1
	end

	if modeId == "pvp" then
		return queueSize >= 2
	end

	if queueSize >= mode.minPlayers then
		return true
	end

	local startedAt = fillStartedAt[modeId]
	if startedAt and mode.fillTimeout and queueSize >= 2 then
		return os.clock() - startedAt >= mode.fillTimeout
	end

	return false
end

local function tryLaunchMatch(modeId)
	if GameMatchState.isBusy() then
		return false
	end

	if not canStartMode(modeId) then
		return false
	end

	local resolvedMode, playerCount = resolveModeForQueue(modeId)
	local players = takePlayersFromQueue(modeId, playerCount)

	if #players == 0 then
		return false
	end

	if resolvedMode.id == "pvp" and #players < 2 then
		for _, player in players do
			table.insert(getQueue(modeId), player)
			playerQueue[player] = modeId
		end
		return false
	end

	if resolvedMode.id == "training" and #players < 1 then
		return false
	end

	Bindables.MatchReady:Fire(players, resolvedMode.id)
	broadcastQueueUpdate()
	return true
end

local function tryLaunchPending()
	if not pendingMatch or GameMatchState.isBusy() then
		return
	end

	local modeId = pendingMatch.modeId
	local players = pendingMatch.players
	pendingMatch = nil

	for _, player in players do
		if player.Parent then
			playerQueue[player] = nil
		end
	end

	Bindables.MatchReady:Fire(players, modeId)
	broadcastQueueUpdate()
end

local function queuePendingMatch(modeId, players)
	pendingMatch = {
		modeId = modeId,
		players = players,
	}

	for _, player in players do
		if player.Parent then
			playerQueue[player] = modeId
		end
	end

	broadcastQueueUpdate()
end

local function attemptStarts()
	if pendingMatch and not GameMatchState.isBusy() then
		tryLaunchPending()
		if GameMatchState.isBusy() then
			return
		end
	end

	for _, mode in MatchModes.all() do
		if canStartMode(mode.id) then
			if GameMatchState.isBusy() then
				local resolvedMode, playerCount = resolveModeForQueue(mode.id)
				local players = {}
				local queue = getQueue(mode.id)
				for i = 1, math.min(playerCount, #queue) do
					table.insert(players, queue[i])
				end
				if #players > 0 then
					for _, player in players do
						removeFromQueue(player, mode.id)
					end
					queuePendingMatch(resolvedMode.id, players)
				end
				return
			end

			tryLaunchMatch(mode.id)
		end
	end
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

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	if not fillStartedAt[modeId] and mode.fillTimeout then
		fillStartedAt[modeId] = os.clock()
	end

	broadcastQueueUpdate(player)
	attemptStarts()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player]
	clearPlayerFromQueues(player)

	if pendingMatch then
		local stillPending = false
		for i, p in pendingMatch.players do
			if p == player then
				table.remove(pendingMatch.players, i)
				break
			end
		end
		for _, p in pendingMatch.players do
			if p.Parent and playerQueue[p] then
				stillPending = true
				break
			end
		end
		if not stillPending then
			pendingMatch = nil
		end
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate()

	if HubService.getPhase(player) == "arena" and not GameMatchState.isBusy() then
		HubService.returnPlayerToHub(player)
	end

	return true
end

function MatchmakingService.joinRecommended(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.recommendForPlayerCount(count)
	return MatchmakingService.joinQueue(player, mode.id)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	task.defer(attemptStarts)
end

function MatchmakingService.requeuePending(players, modeId)
	if typeof(players) ~= "table" or #players == 0 then
		return
	end

	queuePendingMatch(modeId or "training", players)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == nil or modeId == "auto" then
			MatchmakingService.joinRecommended(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	tickTask = task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			attemptStarts()
			broadcastQueueUpdate()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
