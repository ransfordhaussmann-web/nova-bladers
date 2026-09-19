--[[
	MatchmakingService — per-mode queues with fill timeouts and arena-pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReadyBindable
local MatchEndedBindable

local queues = {}
local playerQueue = {}
local fillTimers = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function playerInQueue(player)
	return playerQueue[player] ~= nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if fillTimers[modeId] and #queue < MatchModes.get(modeId).minPlayers then
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local pendingArena = MatchStateService.isArenaBusy()
	local fillDeadline = fillTimers[modeId]

	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		inQueue = playerInQueue(player),
		pendingArena = pendingArena,
		fillSecondsLeft = fillDeadline and math.max(0, math.ceil(fillDeadline - os.clock())) or nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
end

local function broadcastAllQueues()
	for _, mode in MatchModes.all() do
		broadcastQueueUpdate(mode.id)
	end
end

local function isQueueReady(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count >= mode.maxPlayers then
		return true
	end

	if count >= mode.minPlayers then
		if mode.fillTimeout and fillTimers[modeId] then
			return os.clock() >= fillTimers[modeId]
		end
		if not mode.fillTimeout then
			return true
		end
	end

	return false
end

local function takeReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local ready = {}

	for i = 1, count do
		local queuedPlayer = queue[i]
		if queuedPlayer and queuedPlayer.Parent then
			table.insert(ready, queuedPlayer)
		end
	end

	for _, queuedPlayer in ready do
		removeFromQueue(queuedPlayer)
	end

	fillTimers[modeId] = nil
	return ready
end

local function fireMatchReady(players, modeId)
	if #players == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	MatchReadyBindable:Fire({
		players = players,
		mode = modeId,
	})
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	if not isQueueReady(modeId) then
		return
	end

	local players = takeReadyPlayers(modeId)
	if #players == 0 then
		return
	end

	fireMatchReady(players, modeId)
	broadcastAllQueues()
end

local function tryStartAnyMatch()
	for _, mode in MatchModes.all() do
		if isQueueReady(mode.id) and not MatchStateService.isArenaBusy() then
			tryStartMatch(mode.id)
			return
		end
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT
	fillTimers[modeId] = os.clock() + timeout
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "unknown_mode"
	end

	if MatchStateService.isArenaBusy() and not playerInQueue(player) then
		-- Allow joining while arena is busy; players wait in pending state.
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	if #queue >= mode.minPlayers and mode.fillTimeout then
		startFillTimer(modeId)
	end

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)

	if isQueueReady(modeId) then
		tryStartMatch(modeId)
	else
		broadcastQueueUpdate(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerInQueue(player) then
		return false
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)

	Remotes.QueueUpdate:FireClient(player, {
		inQueue = false,
		modeId = modeId,
	})
	broadcastQueueUpdate(modeId)

	return true
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinRecommendedQueue(player)
	return MatchmakingService.joinQueue(player, MatchmakingService.getRecommendedModeId())
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(function()
		tryStartAnyMatch()
		broadcastAllQueues()
	end)
end

function MatchmakingService.onPlayerLeaving(player)
	removeFromQueue(player)
	broadcastAllQueues()
end

function MatchmakingService.init()
	local _, bindables = RemotesSetup.ensure()
	Remotes = ReplicatedStorage.NovaBladers.Remotes
	MatchReadyBindable = bindables.MatchReady
	MatchEndedBindable = bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "recommended" or modeId == nil then
			MatchmakingService.joinRecommendedQueue(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEndedBindable.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for _, mode in MatchModes.all() do
				local modeId = mode.id
				if isQueueReady(modeId) then
					tryStartMatch(modeId)
				else
					local queue = getQueue(modeId)
					if #queue > 0 then
						broadcastQueueUpdate(modeId)
					end
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
