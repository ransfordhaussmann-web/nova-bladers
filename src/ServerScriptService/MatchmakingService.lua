--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local callbacks = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function indexOf(queue, player)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	local idx = indexOf(queue, player)
	if idx then
		table.remove(queue, idx)
	end
	playerQueue[player] = nil
end

local function getQueueStatus(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local position = indexOf(queue, player) or 0

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif mode.minPlayers == 1 and #queue >= 1 then
		status = "ready"
	elseif #queue >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		total = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		queue = getQueueStatus(modeId, player),
	})
end

local function broadcastQueueUpdates(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	cancelFillTimer(modeId)
	local token = fillTokens[modeId] or 0
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function tryDispatchMatch(modeId, roster)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return false
	end

	for _, player in roster do
		removeFromQueue(player)
	end

	cancelFillTimer(modeId)
	broadcastQueueUpdates(modeId)

	if callbacks.onPlayersMatched then
		for _, player in roster do
			callbacks.onPlayersMatched(player)
		end
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(roster, modeId)
	return true
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	local roster = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(roster, queue[i])
	end

	tryDispatchMatch(modeId, roster)
end

local function onQueueChanged(modeId)
	broadcastQueueUpdates(modeId)

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if #queue >= mode.minPlayers then
		if mode.fillTimeout then
			if #queue == mode.minPlayers then
				startFillTimer(modeId)
			end
		else
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId
	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	cancelFillTimer(modeId)
	broadcastQueueUpdates(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.recommendForPlayerCount(count)
	MatchmakingService.joinQueue(player, mode.id)
end

function MatchmakingService.onArenaFreed()
	for _, mode in MatchModes.all() do
		local queue = getQueue(mode.id)
		if #queue >= mode.minPlayers then
			MatchmakingService.tryStartMatch(mode.id)
		else
			broadcastQueueUpdates(mode.id)
		end
	end
end

function MatchmakingService.init(hubCallbacks)
	callbacks = hubCallbacks or {}

	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			MatchmakingService.joinQuickMatch(player)
			return
		end
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerQueue[player]
		if modeId then
			removeFromQueue(player)
			cancelFillTimer(modeId)
			broadcastQueueUpdates(modeId)
		end
	end)
end

return MatchmakingService
