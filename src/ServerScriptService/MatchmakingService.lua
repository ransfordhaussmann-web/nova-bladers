local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local pvpTimers = {}
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
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

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	if pvpTimers[player] then
		task.cancel(pvpTimers[player])
		pvpTimers[player] = nil
	end
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = position,
		count = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status or "waiting",
	}
end

local function sendQueueUpdate(player, modeId, status)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
		sendQueueUpdate(queuedPlayer, modeId, status)
	end
end

local function clearQueue(modeId)
	queues[modeId] = {}
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function startMatch(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
	end
	clearQueue(modeId)

	for _, player in playerList do
		HubService.preparePlayerForArena(player)
		Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	end

	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local playerList = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(playerList, queue[i])
	end

	startMatch(modeId, playerList)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function schedulePvpTimeout(player)
	if pvpTimers[player] then
		task.cancel(pvpTimers[player])
	end

	pvpTimers[player] = task.delay(MatchmakingConfig.PVP_WAIT_TIMEOUT, function()
		pvpTimers[player] = nil
		if playerQueue[player] == "pvp" then
			MatchmakingService.leaveQueue(player)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
	sendQueueUpdate(player, modeId, status)
	broadcastQueueUpdate(modeId)

	if mode.instantStart and #queue >= mode.minPlayers then
		tryStartMatch(modeId)
		return
	end

	if modeId == "pvp" and #queue == 1 then
		schedulePvpTimeout(player)
	elseif mode.fillTimeout and #queue >= mode.minPlayers then
		scheduleFillTimeout(modeId)
	end

	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.getRecommended(count)
	MatchmakingService.joinQueue(player, mode.id)
end

function MatchmakingService.onArenaFreed()
	for modeId in queues do
		if #getQueue(modeId) > 0 then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			MatchmakingService.joinQuickMatch(player)
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

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
