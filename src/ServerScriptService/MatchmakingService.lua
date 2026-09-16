local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local queues = {}
local playerEntry = {}
local fillDeadlines = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerEntry[player] = nil
	fillDeadlines[entry.modeId] = nil
end

local function getQueuePosition(player, modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return 0
end

local function getFillSecondsRemaining(modeId)
	local deadline = fillDeadlines[modeId]
	if not deadline then
		return nil
	end
	return math.max(0, math.ceil(deadline - os.clock()))
end

local function buildUpdatePayload(player)
	local entry = playerEntry[player]
	if not entry then
		return { status = "idle" }
	end

	local mode = MatchModes.get(entry.modeId)
	local queueSize = getQueueSize(entry.modeId)
	local status = entry.status or "waiting"

	if MatchStateService.isBusy() and queueSize >= mode.minPlayers then
		status = "pending"
	end

	return {
		status = status,
		modeId = entry.modeId,
		modeLabel = mode.label,
		position = getQueuePosition(player, entry.modeId),
		queueSize = queueSize,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillSeconds = getFillSecondsRemaining(entry.modeId),
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, player in queue do
		if player.Parent then
			QueueUpdate:FireClient(player, buildUpdatePayload(player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function peekPlayers(modeId, count)
	local queue = queues[modeId]
	local peeked = {}
	for i = 1, math.min(count, #queue) do
		local queuedPlayer = queue[i]
		if queuedPlayer and queuedPlayer.Parent then
			table.insert(peeked, queuedPlayer)
		end
	end
	return peeked
end

local function removePlayersFromQueue(players)
	local affectedModes = {}
	for _, player in players do
		local entry = playerEntry[player]
		if entry then
			affectedModes[entry.modeId] = true
			local queue = queues[entry.modeId]
			if queue then
				for i, queuedPlayer in queue do
					if queuedPlayer == player then
						table.remove(queue, i)
						break
					end
				end
			end
			playerEntry[player] = nil
		end
	end
	for modeId in affectedModes do
		fillDeadlines[modeId] = nil
	end
end

function MatchmakingService.commitPlayers(players)
	removePlayersFromQueue(players)
	broadcastAllQueues()
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queueSize = getQueueSize(modeId)
	if queueSize < mode.minPlayers then
		return false
	end

	if mode.fillTimeout then
		if queueSize >= mode.maxPlayers then
			return true
		end
		local deadline = fillDeadlines[modeId]
		return deadline ~= nil and os.clock() >= deadline
	end

	return true
end

local function tryLaunchMode(modeId)
	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return false
	end

	if not canStartMode(modeId) then
		return false
	end

	local mode = MatchModes.get(modeId)
	local players = peekPlayers(modeId, mode.maxPlayers)
	if #players < mode.minPlayers then
		return false
	end

	for _, queuedPlayer in players do
		HubService.enterArena(queuedPlayer)
	end

	MatchReady:Fire(players, modeId)
	return true
end

local function evaluateMode(modeId)
	local mode = MatchModes.get(modeId)
	local queueSize = getQueueSize(modeId)

	if queueSize < mode.minPlayers then
		fillDeadlines[modeId] = nil
		return
	end

	if mode.fillTimeout and queueSize < mode.maxPlayers and not fillDeadlines[modeId] then
		fillDeadlines[modeId] = os.clock() + mode.fillTimeout
	end

	tryLaunchMode(modeId)
end

local function evaluateAllModes()
	for modeId in queues do
		evaluateMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end

	removeFromQueue(player)

	local queue = queues[modeId]
	table.insert(queue, player)
	playerEntry[player] = {
		modeId = modeId,
		status = "waiting",
	}

	QueueUpdate:FireClient(player, buildUpdatePayload(player))
	evaluateMode(modeId)
	broadcastQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return false
	end

	local modeId = playerEntry[player].modeId
	removeFromQueue(player)
	QueueUpdate:FireClient(player, { status = "idle" })
	broadcastQueue(modeId)
	return true
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true
	initQueues()

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.resolveFromPlayerCount(#Players:GetPlayers())
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		evaluateAllModes()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for modeId in queues do
				local mode = MatchModes.get(modeId)
				if mode.fillTimeout and fillDeadlines[modeId] then
					broadcastQueue(modeId)
					tryLaunchMode(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
