local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local playerStatus = {}
local fillTimers = {}
local pendingMatch = nil

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
	playerStatus[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local status = playerStatus[player] or "waiting"

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		queueSize = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
	}
end

local function broadcastQueueUpdate(player)
	if player.Parent then
		QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllInQueue(modeId)
	for _, queuedPlayer in getQueue(modeId) do
		broadcastQueueUpdate(queuedPlayer)
	end
end

local function canStartMatch(mode, queue)
	if #queue < mode.minPlayers then
		return false
	end
	if mode.id == "ffa" then
		return #queue >= mode.maxPlayers
	end
	return #queue >= mode.maxPlayers
end

local function popPlayers(mode)
	local queue = getQueue(mode.id)
	local count = math.min(#queue, mode.maxPlayers)
	local players = {}
	for _ = 1, count do
		table.insert(players, table.remove(queue, 1))
	end
	return players
end

local function clearPlayerFromQueue(player)
	removeFromQueue(player)
	broadcastQueueUpdate(player)
end

local function launchMatch(modeId, players)
	for _, player in players do
		playerQueue[player] = nil
		playerStatus[player] = nil
		broadcastQueueUpdate(player)
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if not canStartMatch(mode, queue) then
		return
	end

	local players = popPlayers(mode)
	if #players == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = { modeId = modeId, players = players }
		for _, player in players do
			playerStatus[player] = "pending"
			broadcastQueueUpdate(player)
		end
		return
	end

	launchMatch(modeId, players)
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode or mode.id ~= "ffa" then
		return
	end

	fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers[modeId] = nil
		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if mode.id == "ffa" then
		if #queue >= mode.maxPlayers then
			tryStartMatch(modeId)
		else
			startFillTimer(modeId)
		end
	else
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	playerStatus[player] = "waiting"
	broadcastAllInQueue(modeId)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	broadcastQueueUpdate(player)
	broadcastAllInQueue(modeId)

	if pendingMatch then
		for i, p in pendingMatch.players do
			if p == player then
				table.remove(pendingMatch.players, i)
				break
			end
		end
		if #pendingMatch.players == 0 then
			pendingMatch = nil
		end
	end
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(handlers)
	MatchStateService.onArenaFreed(function()
		if pendingMatch then
			local match = pendingMatch
			pendingMatch = nil
			launchMatch(match.modeId, match.players)
		else
			for modeId in queues do
				evaluateQueue(modeId)
			end
		end
	end)

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if handlers and handlers.onJoinArena then
			handlers.onJoinArena(player)
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		if handlers and handlers.onLeaveQueue then
			handlers.onLeaveQueue(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearPlayerFromQueue(player)
		if pendingMatch then
			for i, p in pendingMatch.players do
				if p == player then
					table.remove(pendingMatch.players, i)
					break
				end
			end
			if #pendingMatch.players == 0 then
				pendingMatch = nil
			end
		end
	end)
end

return MatchmakingService
