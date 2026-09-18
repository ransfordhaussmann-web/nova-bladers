--[[
	MatchmakingService — per-mode queues with fill timeout and arena-pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local pendingStarts = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
	return queues[modeId]
end

local function queueCount(modeId)
	local queue = getQueue(modeId)
	local count = 0
	for _ in queue.players do
		count += 1
	end
	return count
end

local function getQueuedPlayers(modeId)
	local queue = getQueue(modeId)
	local list = {}
	for player in queue.players do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function getStatus(modeId, count)
	local mode = MatchModes.get(modeId)
	if not mode then
		return "waiting"
	end

	if pendingStarts[modeId] then
		return "pending"
	end

	if count >= mode.maxPlayers then
		return "starting"
	end

	local queue = getQueue(modeId)
	if mode.fillTimeout > 0 and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return "starting"
	end

	if count >= mode.minPlayers and mode.fillTimeout == 0 then
		return "starting"
	end

	return "waiting"
end

local function buildUpdatePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = getQueue(modeId)
	local count = queueCount(modeId)
	local status = getStatus(modeId, count)
	local timeRemaining = nil

	if queue.fillDeadline and status == "waiting" then
		timeRemaining = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = playerQueue[player] == modeId,
		modeId = modeId,
		label = mode.label,
		count = count,
		min = mode.minPlayers,
		max = mode.maxPlayers,
		status = status,
		timeRemaining = timeRemaining,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local payload = buildUpdatePayload(modeId, player)
	if payload then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdate(modeId)
	for player, queuedMode in playerQueue do
		if queuedMode == modeId and player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	queue.players[player] = nil
	playerQueue[player] = nil

	if queueCount(modeId) < MatchModes.get(modeId).minPlayers then
		queue.fillDeadline = nil
	end

	pendingStarts[modeId] = nil
	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if mode.fillTimeout > 0 then
		local queue = getQueue(modeId)
		return queue.fillDeadline ~= nil and os.clock() >= queue.fillDeadline
	end

	return count >= mode.minPlayers
end

local function clearQueue(modeId)
	local queue = getQueue(modeId)
	for player in queue.players do
		playerQueue[player] = nil
		sendQueueUpdate(player)
	end
	queue.players = {}
	queue.fillDeadline = nil
	pendingStarts[modeId] = nil
end

local function launchMatch(modeId)
	local players = getQueuedPlayers(modeId)
	if #players == 0 then
		pendingStarts[modeId] = nil
		return
	end

	clearQueue(modeId)

	for _, player in players do
		HubService.enterArena(player)
	end

	MatchReady:Fire({
		mode = modeId,
		players = players,
	})
end

local function tryStartMatch(modeId)
	if not canStartMatch(modeId) then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingStarts[modeId] = true
		broadcastQueueUpdate(modeId)
		return
	end

	launchMatch(modeId)
end

local function updateFillDeadline(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = queueCount(modeId)

	if mode.fillTimeout > 0 and count >= mode.minPlayers and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + mode.fillTimeout
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	queue.players[player] = true
	playerQueue[player] = modeId

	updateFillDeadline(modeId)
	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getRecommendedModeId()
	return MatchModes.getRecommended(#Players:GetPlayers()).id
end

function MatchmakingService.onArenaFreed()
	for modeId in queues do
		if pendingStarts[modeId] and canStartMatch(modeId) then
			launchMatch(modeId)
			return
		end
	end
end

function MatchmakingService.init(remotes, bindables)
	Remotes = remotes
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for modeId in queues do
				if queueCount(modeId) > 0 then
					tryStartMatch(modeId)
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)
end

return MatchmakingService
