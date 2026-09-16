local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local ffaTimers = {}
local started = false

for _, mode in MatchModes.all() do
	queues[mode.id] = {}
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function removeFromQueue(player)
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

	if modeId == "ffa" and ffaTimers[modeId] then
		ffaTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = queues[modeId] or {}
	local count = #queue
	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	local fillTimeout
	if modeId == "ffa" and ffaTimers[modeId] then
		fillTimeout = math.max(0, math.ceil(ffaTimers[modeId].endsAt - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeout = fillTimeout,
		inQueue = player ~= nil and playerQueue[player] ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId)
	if not payload then
		return
	end

	for _, queuedPlayer in queues[modeId] or {} do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function broadcastAllQueues()
	for _, mode in MatchModes.all() do
		broadcastQueueUpdate(mode.id)
	end
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local queue = queues[modeId]
	if not queue or #queue < mode.minPlayers then
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	Bindables.MatchReady:Fire(modeId, matchPlayers)
end

local function startFfaFillTimer(modeId)
	if ffaTimers[modeId] then
		return
	end

	local endsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	ffaTimers[modeId] = { endsAt = endsAt }

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		ffaTimers[modeId] = nil
		if getQueueSize(modeId) >= MatchModes.get(modeId).minPlayers then
			tryStartMatch(modeId)
		else
			broadcastQueueUpdate(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	removeFromQueue(player)

	local queue = queues[modeId]
	for _, queuedPlayer in queue do
		if queuedPlayer == player then
			return true
		end
	end

	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }

	if modeId == "ffa" and #queue >= mode.minPlayers and not ffaTimers[modeId] then
		startFfaFillTimer(modeId)
	end

	if #queue >= mode.minPlayers and modeId ~= "ffa" then
		tryStartMatch(modeId)
	elseif modeId == "ffa" and #queue >= mode.maxPlayers then
		if ffaTimers[modeId] then
			ffaTimers[modeId] = nil
		end
		tryStartMatch(modeId)
	else
		broadcastQueueUpdate(modeId)
	end

	return true
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.pickQuickMatch(count)
	return MatchmakingService.joinQueue(player, mode.id)
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	removeFromQueue(player)
	broadcastQueueUpdate(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(function()
		for _, mode in MatchModes.all() do
			tryStartMatch(mode.id)
		end
	end)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
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
		for _, mode in MatchModes.all() do
			tryStartMatch(mode.id)
		end
	end)
end

return MatchmakingService
