local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local ffaFillToken = {}
local onMatchStart
local started = false

local function initQueues()
	for _, modeId in MatchModes.all() do
		queues[modeId] = {}
	end
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function buildQueuePayload(player, modeId)
	local queue = queues[modeId] or {}
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local mode = MatchModes.get(modeId)
	local pending = GameMatchState.isArenaBusy()

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = position,
		queueSize = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		pending = pending,
		status = pending and "pending" or "waiting",
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for _, modeId in MatchModes.all() do
		broadcastQueue(modeId)
	end
end

local function cancelFfaFill(modeId)
	ffaFillToken[modeId] = (ffaFillToken[modeId] or 0) + 1
end

local function scheduleFfaFill(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	cancelFfaFill(modeId)
	local token = (ffaFillToken[modeId] or 0) + 1
	ffaFillToken[modeId] = token

	task.spawn(function()
		task.wait(MatchmakingConfig.FFA_FILL_TIMEOUT)
		if ffaFillToken[modeId] ~= token then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	if GameMatchState.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = queues[modeId]
	if not queue or #queue < mode.minPlayers then
		return false
	end

	local matchPlayers = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for i = #matchPlayers, 1, -1 do
		local player = matchPlayers[i]
		for qi = #queue, 1, -1 do
			if queue[qi] == player then
				table.remove(queue, qi)
			end
		end
		playerQueue[player] = nil
	end

	cancelFfaFill(modeId)
	broadcastAllQueues()

	if onMatchStart then
		onMatchStart(matchPlayers, modeId)
	end

	Bindables.MatchReady:Fire(matchPlayers, modeId)
	return true
end

local function maybeStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local size = getQueueSize(modeId)
	if size >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if mode.fillTimeout and size >= mode.minPlayers then
		scheduleFfaFill(modeId)
		return
	end

	if not mode.fillTimeout and size >= mode.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i = #queue, 1, -1 do
			if queue[i] == player then
				table.remove(queue, i)
			end
		end
	end

	playerQueue[player] = nil
	cancelFfaFill(modeId)

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, {
			modeId = nil,
			status = "idle",
		})
	end

	broadcastQueue(modeId)
	maybeStartMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	broadcastQueue(modeId)
	maybeStartMatch(modeId)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start(handlers)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()
	onMatchStart = handlers and handlers.onMatchStart

	GameMatchState.onArenaFree(function()
		broadcastAllQueues()
		for _, modeId in MatchModes.all() do
			maybeStartMatch(modeId)
		end
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
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			for _, modeId in MatchModes.all() do
				if getQueueSize(modeId) > 0 then
					broadcastQueue(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
