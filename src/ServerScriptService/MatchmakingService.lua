local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables = RemotesSetup.ensure()
local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		if not queues[mode.id] then
			queues[mode.id] = {}
		end
	end
end

initQueues()

local function getQueueSize(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	local count = 0
	for _ in queue do
		count += 1
	end
	return count
end

local function buildQueuePayload(modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local size = getQueueSize(modeId)
	local payload = {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		playersInQueue = size,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}

	if mode.fillTimeout and size >= mode.minPlayers and fillTimers[modeId] then
		payload.fillTimeout = mode.fillTimeout
	end

	return payload
end

local function broadcastQueueUpdate(modeId, status)
	local payload = buildQueuePayload(modeId, status)
	if not payload then
		return
	end

	for player in queues[modeId] do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	queues[modeId][player] = nil
	playerQueue[player] = nil

	if fillTimers[modeId] and getQueueSize(modeId) < MatchModes.get(modeId).minPlayers then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end

	broadcastQueueUpdate(modeId, MatchStateService.isBusy() and "pending" or "waiting")
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return false
	end
	if mode.fillTimeout and size < mode.maxPlayers and fillTimers[modeId] then
		return false
	end
	return true
end

local function collectPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local list = {}
	for player in queues[modeId] do
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(list, player)
		end
	end

	table.sort(list, function(a, b)
		local ea = playerQueue[a]
		local eb = playerQueue[b]
		return (ea and ea.joinedAt or 0) < (eb and eb.joinedAt or 0)
	end)

	local matchPlayers = {}
	for i = 1, math.min(#list, mode.maxPlayers) do
		table.insert(matchPlayers, list[i])
	end
	return matchPlayers
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	local token = { cancelled = false }
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if token.cancelled or fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId, "pending")
		return false
	end

	if not canStartMatch(modeId) then
		return false
	end

	local matchPlayers = collectPlayers(modeId)
	local mode = MatchModes.get(modeId)
	if #matchPlayers < mode.minPlayers then
		return false
	end

	clearFillTimer(modeId)

	local startingPayload = {
		modeId = modeId,
		modeLabel = mode.label,
		status = "starting",
		playersInQueue = #matchPlayers,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	for _, player in matchPlayers do
		if HubService.prepareForMatch then
			HubService.prepareForMatch(player)
		end
	end

	for _, player in matchPlayers do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, startingPayload)
		end
	end

	MatchStateService.setBusy(true)
	Bindables.MatchReady:Fire(matchPlayers, modeId)

	return true
end

function MatchmakingService.tryStartAnyMatch()
	for _, mode in MatchModes.all() do
		if MatchmakingService.tryStartMatch(mode.id) then
			return true
		end
	end
	return false
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	if MatchStateService.isBusy() and getQueueSize(modeId) >= mode.maxPlayers then
		return false, "arena_busy"
	end

	removeFromQueue(player)

	queues[modeId][player] = true
	playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	local status = MatchStateService.isBusy() and "pending" or "waiting"
	broadcastQueueUpdate(modeId, status)

	if mode.fillTimeout and getQueueSize(modeId) >= mode.minPlayers then
		startFillTimer(modeId)
	end

	if not MatchStateService.isBusy() then
		if modeId == "training" or modeId == "pvp" then
			MatchmakingService.tryStartMatch(modeId)
		elseif getQueueSize(modeId) >= mode.maxPlayers then
			clearFillTimer(modeId)
			MatchmakingService.tryStartMatch(modeId)
		end
	end

	return true
end

function MatchmakingService.joinRecommendedQueue(player)
	local count = #Players:GetPlayers()
	local modeId = MatchModes.getRecommendedId(count)
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "auto" then
			MatchmakingService.joinRecommendedQueue(player)
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

	MatchStateService.onArenaFree(function()
		MatchmakingService.tryStartAnyMatch()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for _, mode in MatchModes.all() do
				if getQueueSize(mode.id) > 0 then
					local status = MatchStateService.isBusy() and "pending" or "waiting"
					broadcastQueueUpdate(mode.id, status)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
