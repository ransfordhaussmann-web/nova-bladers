local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingCounts = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function buildQueuePayload(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local status = "waiting"
	if pendingCounts[modeId] then
		status = "pending"
	elseif mode.fillTimeout and #queue >= mode.minPlayers then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeout = mode.fillTimeout,
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId)
	for _, queuedPlayer in queues[modeId] do
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

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	broadcastQueue(modeId)
end

local function addToQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId))
	broadcastQueue(modeId)

	return true
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerQueue[player] = nil
			Remotes.QueueUpdate:FireClient(player, { status = "matched", modeId = modeId })
		end
	end
	broadcastQueue(modeId)
	return picked
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function launchPlayers(modeId, count)
	if MatchStateService.isBusy() then
		pendingCounts[modeId] = count
		broadcastQueue(modeId)
		return
	end

	pendingCounts[modeId] = nil
	clearFillTimer(modeId)

	local players = popPlayers(modeId, count)
	if #players == 0 then
		return
	end

	MatchStateService.setBusy(true)
	Bindables.MatchReady:Fire(players, modeId)
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or #queue < mode.minPlayers then
		return
	end

	if pendingCounts[modeId] then
		return
	end

	if mode.id == "training" then
		launchPlayers(modeId, 1)
		return
	end

	if mode.id == "pvp" then
		if #queue >= 2 then
			launchPlayers(modeId, 2)
		end
		return
	end

	if mode.id == "ffa" then
		if #queue >= mode.maxPlayers then
			launchPlayers(modeId, mode.maxPlayers)
			return
		end

		if #queue >= mode.minPlayers and not fillTimers[modeId] then
			broadcastQueue(modeId)
			fillTimers[modeId] = task.delay(mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				fillTimers[modeId] = nil
				if #queues[modeId] >= mode.minPlayers then
					launchPlayers(modeId, #queues[modeId])
				end
			end)
		end
	end
end

local function tryStartAll()
	for modeId in queues do
		tryStartMode(modeId)
	end
end

local function tryLaunchPending()
	for modeId, count in pendingCounts do
		if not MatchStateService.isBusy() then
			launchPlayers(modeId, count)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if playerQueue[player] then
		return false, "already_queued"
	end

	local ok, err = addToQueue(player, modeId)
	if not ok then
		return false, err
	end

	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	clearFillTimer(modeId)
	pendingCounts[modeId] = nil

	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		tryLaunchPending()
		tryStartAll()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
