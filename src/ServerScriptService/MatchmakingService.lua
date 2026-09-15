local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function initQueues()
	for _, modeId in MatchModes.all() do
		queues[modeId] = {}
	end
end

local function getQueueStatus(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local list = queues[modeId]
	local count = #list
	local status = "searching"
	local label = MatchmakingConfig.SEARCHING_LABEL

	if MatchStateService.isBusy() then
		status = "pending"
		label = MatchmakingConfig.PENDING_LABEL
	elseif modeId == "training" and count >= 1 then
		status = "ready"
		label = MatchmakingConfig.READY_LABEL
	elseif count >= mode.maxPlayers then
		status = "ready"
		label = MatchmakingConfig.READY_LABEL
	elseif mode.fillTimeout and count >= mode.minPlayers then
		status = "filling"
		label = string.format("Start in ≤%ds…", mode.fillTimeout)
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		label = label,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function buildPlayerUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local list = queues[modeId]
	local position = 0
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = getQueueStatus(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = status.modeLabel,
		position = position,
		count = status.count,
		minPlayers = status.minPlayers,
		maxPlayers = status.maxPlayers,
		status = status.status,
		label = status.label,
		arenaBusy = status.arenaBusy,
	}
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end
	local payload = buildPlayerUpdate(player)
	if payload then
		QueueUpdate:FireClient(player, payload)
	else
		QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function broadcastQueue(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendQueueUpdate(queuedPlayer)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local list = queues[modeId]
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, i)
			break
		end
	end

	if #list < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	if not silent then
		sendQueueUpdate(player)
		broadcastQueue(modeId)
	end
end

local function popPlayers(modeId, count)
	local list = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #list) do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	clearFillTimer(modeId)
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setBusy(true)
	for _, player in playerList do
		sendQueueUpdate(player)
	end
	for _, mode in MatchModes.all() do
		broadcastQueue(mode)
	end

	MatchReady:Fire(modeId, playerList)
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local list = queues[modeId]
	if #list < mode.minPlayers then
		return
	end

	if modeId == "training" then
		startMatch(modeId, popPlayers(modeId, 1))
		return
	end

	if #list >= mode.maxPlayers then
		startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		return
	end

	if mode.fillTimeout and #list >= mode.minPlayers and not fillTimers[modeId] then
		broadcastQueue(modeId)
		fillTimers[modeId] = task.delay(mode.fillTimeout, function()
			fillTimers[modeId] = nil
			if MatchStateService.isBusy() then
				return
			end
			local current = queues[modeId]
			if #current >= mode.minPlayers then
				startMatch(modeId, popPlayers(modeId, #current))
			end
		end)
	end
end

local function tryStartAll()
	for _, modeId in MatchModes.all() do
		tryStartMode(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player, false)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player, true)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	sendQueueUpdate(player)
	broadcastQueue(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local modeId = "training"
	if count >= 3 then
		modeId = "ffa"
	elseif count >= 2 then
		modeId = "pvp"
	end
	MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(tryStartAll)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true
	initQueues()

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
