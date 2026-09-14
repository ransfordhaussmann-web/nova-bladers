local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubService

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerToMode = {}
local pendingReady = nil
local started = false

local function initQueues()
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {
			players = {},
			fillDeadline = nil,
			fillToken = 0,
		}
	end
end

local function getRecommendedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function resolveModeId(modeId)
	if modeId == "auto" or modeId == nil then
		return getRecommendedMode()
	end
	if MatchModes.isValid(modeId) then
		return modeId
	end
	return getRecommendedMode()
end

local function buildPlayerUpdate(player)
	local modeId = playerToMode[player]
	if not modeId then
		return {
			inQueue = false,
			arenaBusy = GameMatchState.isArenaBusy(),
		}
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local isPending = false
	if pendingReady then
		for _, pendingPlayer in pendingReady.players do
			if pendingPlayer == player then
				isPending = true
				break
			end
		end
	end

	local fillSecondsLeft = nil
	if queue.fillDeadline then
		fillSecondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue.players,
		needed = mode.minPlayers,
		max = mode.maxPlayers,
		arenaBusy = GameMatchState.isArenaBusy(),
		pending = isPending,
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
		end
	end
end

local function clearFillTimer(modeId)
	local queue = queues[modeId]
	queue.fillDeadline = nil
	queue.fillToken += 1
end

local function removeFromQueue(player)
	local modeId = playerToMode[player]
	if not modeId then
		return
	end

	playerToMode[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end
	clearFillTimer(modeId)
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local matched = {}
	for index = 1, math.min(count, #queue.players) do
		local player = queue.players[index]
		table.insert(matched, player)
		playerToMode[player] = nil
	end

	for _, player in matched do
		for queueIndex, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, queueIndex)
				break
			end
		end
	end

	clearFillTimer(modeId)
	return matched
end

local function leaveHubForMatch(players)
	for _, player in players do
		if player.Parent and HubService.leaveHubForArena then
			HubService.leaveHubForArena(player)
		end
	end
end

local function fireMatchReady(modeId, players)
	leaveHubForMatch(players)
	MatchReady:Fire(players, modeId)
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	if count >= mode.maxPlayers then
		return true, mode.maxPlayers
	end

	if modeId == "training" and count >= 1 then
		return true, 1
	end

	if modeId == "pvp" and count >= 2 then
		return true, 2
	end

	if modeId == "ffa" and count >= mode.minPlayers then
		if queue.fillDeadline and os.clock() >= queue.fillDeadline then
			return true, count
		end
	end

	return false, 0
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	local queue = queues[modeId]
	if queue.fillDeadline then
		return
	end

	queue.fillDeadline = os.clock() + mode.fillTimeout
	queue.fillToken += 1
	local token = queue.fillToken

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken or not queue.fillDeadline then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	local ready, playerCount = canStartMatch(modeId)
	if not ready then
		return
	end

	local matched = takePlayers(modeId, playerCount)
	if #matched == 0 then
		return
	end

	if GameMatchState.isArenaBusy() then
		pendingReady = {
			modeId = modeId,
			players = matched,
		}
		for _, player in matched do
			playerToMode[player] = modeId
		end
		broadcastQueueUpdate()
		return
	end

	pendingReady = nil
	fireMatchReady(modeId, matched)
	broadcastQueueUpdate()
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return
	end

	local resolvedMode = resolveModeId(modeId)
	removeFromQueue(player)
	playerToMode[player] = resolvedMode
	table.insert(queues[resolvedMode].players, player)

	local mode = MatchModes.get(resolvedMode)
	local queue = queues[resolvedMode]

	if resolvedMode == "ffa" and #queue.players >= mode.minPlayers then
		startFillTimer(resolvedMode)
	end

	broadcastQueueUpdate()
	MatchmakingService.tryStartMatch(resolvedMode)
end

function MatchmakingService.leaveQueue(player)
	if not playerToMode[player] and not pendingReady then
		return
	end

	if pendingReady then
		for index, pendingPlayer in pendingReady.players do
			if pendingPlayer == player then
				table.remove(pendingReady.players, index)
				playerToMode[player] = nil
				if #pendingReady.players == 0 then
					pendingReady = nil
				end
				broadcastQueueUpdate()
				return
			end
		end
	end

	removeFromQueue(player)
	broadcastQueueUpdate()
end

function MatchmakingService.requeuePending(modeId, players)
	pendingReady = {
		modeId = modeId,
		players = players,
	}
	for _, player in players do
		if player.Parent then
			playerToMode[player] = modeId
		end
	end
	broadcastQueueUpdate()
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaBusy(false)

	if pendingReady and #pendingReady.players > 0 then
		local pending = pendingReady
		pendingReady = nil
		local validPlayers = {}
		for _, player in pending.players do
			playerToMode[player] = nil
			if player.Parent then
				table.insert(validPlayers, player)
			end
		end
		if #validPlayers > 0 then
			fireMatchReady(pending.modeId, validPlayers)
		end
	else
		pendingReady = nil
		for _, mode in MatchModes.getAll() do
			MatchmakingService.tryStartMatch(mode.id)
		end
	end

	broadcastQueueUpdate()
end

function MatchmakingService.getRecommendedMode()
	return getRecommendedMode()
end

function MatchmakingService.start(hubServiceRef)
	if started then
		return
	end
	started = true

	HubService = hubServiceRef
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
