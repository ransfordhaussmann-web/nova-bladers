--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

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
local MatchEnded = Bindables.MatchEnded

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getQueuePosition(modeId, player)
	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function removeFromAllQueues(player)
	local previousMode = playerQueue[player]
	if not previousMode then
		return nil
	end

	local queue = ensureQueue(previousMode)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[previousMode] and #queue < MatchModes.get(previousMode).minPlayers then
		fillTimers[previousMode].cancelled = true
		fillTimers[previousMode] = nil
	end

	return previousMode
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local position = getQueuePosition(modeId, player)

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = ensureQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
			QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer, modeId, status))
		end
	end
end

local function clearQueue(modeId)
	queues[modeId] = {}
	fillTimers[modeId] = nil
end

local hubCallbacks = nil

local function startMatch(modeId, playerList)
	clearQueue(modeId)

	for _, queuedPlayer in playerList do
		playerQueue[queuedPlayer] = nil
		QueueLeave:FireClient(queuedPlayer)
	end

	if hubCallbacks and hubCallbacks.onMatchStart then
		hubCallbacks.onMatchStart(playerList)
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(modeId, playerList)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = { modeId = modeId, players = table.clone(queue) }
		broadcastQueueUpdate(modeId)
		return
	end

	local playerList = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(playerList, queue[i])
	end

	startMatch(modeId, playerList)
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.id ~= "ffa" then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = { cancelled = false }
	fillTimers[modeId] = token

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token.cancelled or fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		return true, "already_queued"
	end

	removeFromAllQueues(player)

	local queue = ensureQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
	QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))

	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers and mode.id == "ffa" then
		startFillTimer(modeId)
	elseif #queue >= mode.minPlayers then
		tryStartMatch(modeId)
	end

	broadcastQueueUpdate(modeId)
	return true, "joined"
end

local function leaveQueue(player)
	local modeId = removeFromAllQueues(player)
	if modeId then
		QueueLeave:FireClient(player)
		broadcastQueueUpdate(modeId)
	end
end

local function resolveQuickMatchMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.requestJoin(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	if modeId == "quick" then
		modeId = resolveQuickMatchMode()
	end

	local ok, reason = joinQueue(player, modeId)
	if not ok and reason == "queue_full" then
		QueueUpdate:FireClient(player, {
			modeId = modeId,
			status = "full",
			arenaBusy = MatchStateService.isArenaBusy(),
		})
	end
	return ok, reason
end

function MatchmakingService.init(callbacks)
	hubCallbacks = callbacks

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.requestJoin(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchStateService.setArenaBusy(false)

		if pendingMatch then
			local pending = pendingMatch
			pendingMatch = nil
			local validPlayers = {}
			for _, queuedPlayer in pending.players do
				if queuedPlayer.Parent then
					table.insert(validPlayers, queuedPlayer)
				end
			end
			if #validPlayers > 0 then
				startMatch(pending.modeId, validPlayers)
			end
			return
		end

		for _, mode in MatchModes.getAll() do
			tryStartMatch(mode.id)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

return MatchmakingService
