local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady
local MatchEnded

local queues = {}
local playerQueue = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
			pending = false,
		}
	end
	return queues[modeId]
end

local function getQueueCount(modeId)
	return #ensureQueue(modeId).players
end

local function removeFromQueueList(queue, player)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			return true
		end
	end
	return false
end

local function clearPlayerFromQueues(player)
	local previousMode = playerQueue[player]
	if not previousMode then
		return
	end

	local queue = queues[previousMode]
	if queue then
		removeFromQueueList(queue, player)
		if #queue.players < MatchModes.get(previousMode).minPlayers then
			queue.fillDeadline = nil
			queue.pending = false
		end
	end
	playerQueue[player] = nil
end

local function buildUpdatePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return {
			inQueue = false,
		}
	end

	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players
	local fillRemaining = nil
	if queue.fillDeadline then
		fillRemaining = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	local status = "queued"
	if queue.pending then
		status = "pending"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		playersInQueue = count,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeRemaining = fillRemaining,
	}
end

local function broadcastQueueUpdate(targetPlayer)
	if targetPlayer and targetPlayer.Parent then
		Remotes.QueueUpdate:FireClient(targetPlayer, buildUpdatePayload(targetPlayer))
	end
end

local function broadcastAllQueued()
	for player in playerQueue do
		if player.Parent then
			broadcastQueueUpdate(player)
		end
	end
end

local function canStartMode(queue, mode)
	local count = #queue.players
	if count < mode.minPlayers then
		return false
	end
	if mode.maxPlayers and count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true
	end
	if not mode.fillTimeout and count >= mode.minPlayers then
		return true
	end
	return false
end

local function launchMatch(modeId, queue)
	local mode = MatchModes.get(modeId)
	local matchPlayers = {}
	local take = math.min(#queue.players, mode.maxPlayers)

	for i = 1, take do
		table.insert(matchPlayers, queue.players[i])
	end

	for _, player in matchPlayers do
		playerQueue[player] = nil
	end

	for i = take, 1, -1 do
		table.remove(queue.players, i)
	end

	if #queue.players < mode.minPlayers then
		queue.fillDeadline = nil
	end
	queue.pending = false

	for _, player in matchPlayers do
		if player.Parent then
			broadcastQueueUpdate(player)
			if HubService.getPhase(player) == "hub" then
				HubService.leaveHubForArena(player)
			end
		end
	end

	MatchReady:Fire({
		players = matchPlayers,
		modeId = modeId,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	if not canStartMode(queue, mode) then
		return
	end

	if MatchStateService.isArenaBusy() then
		queue.pending = true
		broadcastAllQueued()
		return
	end

	launchMatch(modeId, queue)
	broadcastAllQueued()
end

local function evaluateQueues()
	for modeId, _ in pairs(MatchModes.getAll()) do
		local mode = MatchModes.get(modeId)
		local queue = ensureQueue(modeId)
		local count = #queue.players

		if count >= mode.minPlayers and mode.fillTimeout and not queue.fillDeadline then
			queue.fillDeadline = os.clock() + mode.fillTimeout
		elseif count < mode.minPlayers then
			queue.fillDeadline = nil
			queue.pending = false
		end

		tryStartMatch(modeId)
	end
end

local function processPending()
	for modeId, _ in pairs(MatchModes.getAll()) do
		local queue = ensureQueue(modeId)
		if queue.pending and canStartMode(queue, MatchModes.get(modeId)) and not MatchStateService.isArenaBusy() then
			launchMatch(modeId, queue)
		end
	end
	broadcastAllQueued()
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end
	if playerQueue[player] == modeId then
		broadcastQueueUpdate(player)
		return true
	end

	clearPlayerFromQueues(player)

	local queue = ensureQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(player)
	broadcastAllQueued()
	evaluateQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		broadcastQueueUpdate(player)
		return
	end

	clearPlayerFromQueues(player)
	broadcastQueueUpdate(player)
	broadcastAllQueued()
	evaluateQueues()
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.getRecommendedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return MatchModes.FFA
	elseif count == 2 then
		return MatchModes.PVP
	end
	return MatchModes.TRAINING
end

function MatchmakingService.getQueueCount(modeId)
	return getQueueCount(modeId)
end

function MatchmakingService.init()
	Remotes, _ = RemotesSetup.ensure()
	local bindables = ReplicatedStorage.NovaBladers.Bindables
	MatchReady = bindables.MatchReady
	MatchEnded = bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedMode()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		task.defer(processPending)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			evaluateQueues()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
