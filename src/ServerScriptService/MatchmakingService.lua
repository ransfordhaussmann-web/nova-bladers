local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local callbacks = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getMode(modeId)
	return MatchModes.get(modeId) or MatchModes.training
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
end

local function buildQueuePayload(player, modeId)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = status,
		pendingLabel = MatchmakingConfig.PENDING_LABEL,
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function cancelFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode.fillTimeout then
		return
	end

	cancelFillTimer(modeId)
	local token = {}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local mode = getMode(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	local matchPlayers = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end
	cancelFillTimer(modeId)
	broadcastQueue(modeId)

	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, matchPlayers)
	end

	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false
	end

	modeId = modeId or MatchModes.recommendForPlayerCount(#Players:GetPlayers()).id
	if not MatchModes.get(modeId) then
		return false
	end

	if playerQueue[player] == modeId then
		broadcastQueue(modeId)
		return true
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	if callbacks.onPlayerQueued then
		callbacks.onPlayerQueued(player, modeId)
	end

	broadcastQueue(modeId)

	local mode = getMode(modeId)
	if #getQueue(modeId) >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif mode.fillTimeout and #getQueue(modeId) >= mode.minPlayers then
		startFillTimer(modeId)
	elseif mode.minPlayers == 1 and #getQueue(modeId) >= 1 then
		MatchmakingService.tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local mode = getMode(modeId)
	removeFromQueue(player)
	local queue = getQueue(modeId)
	if mode.fillTimeout and #queue < mode.minPlayers then
		cancelFillTimer(modeId)
	end
	broadcastQueue(modeId)

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { status = "left" })
	end

	if callbacks.onPlayerLeftQueue then
		callbacks.onPlayerLeftQueue(player)
	end
end

function MatchmakingService.onArenaFreed()
	for _, mode in MatchModes.all() do
		broadcastQueue(mode.id)
		MatchmakingService.tryStartMatch(mode.id)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.init(hubCallbacks)
	callbacks = hubCallbacks or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.recommendForPlayerCount(#Players:GetPlayers()).id
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchStateService.setArenaBusy(false)
		task.defer(function()
			MatchmakingService.onArenaFreed()
		end)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
