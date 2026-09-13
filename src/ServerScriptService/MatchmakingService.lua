local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local fillTimers = {}
local broadcastScheduled = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
	return token
end

local function cancelFillTimer(modeId)
	clearFillTimer(modeId)
end

local function startFillTimer(modeId, mode)
	cancelFillTimer(modeId)
	local token = {}
	fillTimers[modeId] = token

	local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT
	task.delay(timeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
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

	if #queue < (MatchModes.get(modeId) and MatchModes.get(modeId).minPlayers or 1) then
		cancelFillTimer(modeId)
	end
end

local function buildQueueSnapshot(player)
	local modeId = playerQueue[player]
	if not modeId then
		return {
			status = MatchmakingConfig.STATUS.Idle,
		}
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local status = MatchmakingConfig.STATUS.Queued

	if pendingMatch and GameMatchState.isBusy() then
		for _, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				status = MatchmakingConfig.STATUS.Pending
				break
			end
		end
	end

	local needed = math.max(0, mode.minPlayers - count)
	local fillRemaining = nil
	if modeId == "ffa" and count >= mode.minPlayers and fillTimers[modeId] then
		fillRemaining = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT
	end

	return {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		queueCount = count,
		needed = needed,
		maxPlayers = mode.maxPlayers,
		fillRemaining = fillRemaining,
		arenaBusy = GameMatchState.isBusy(),
	}
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueueSnapshot(player))
end

local function broadcastQueueUpdates()
	if broadcastScheduled then
		return
	end
	broadcastScheduled = true
	task.delay(MatchmakingConfig.QUEUE_BROADCAST_DEBOUNCE, function()
		broadcastScheduled = false
		for player in playerQueue do
			sendQueueUpdate(player)
		end
	end)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdates()
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	sendQueueUpdate(player)
	broadcastQueueUpdates()

	if modeId == "ffa" and #queue >= mode.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId, mode)
	end

	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.joinRecommended(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.recommendForPlayerCount(count)
	MatchmakingService.joinQueue(player, mode.id)
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

	if GameMatchState.isBusy() then
		local roster = {}
		for i = 1, math.min(#queue, mode.maxPlayers) do
			table.insert(roster, queue[i])
		end
		pendingMatch = {
			modeId = modeId,
			players = roster,
		}
		for _, player in roster do
			sendQueueUpdate(player)
		end
		return
	end

	local roster = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[i]
		table.insert(roster, player)
		playerQueue[player] = nil
	end

	for i = 1, #roster do
		table.remove(queue, 1)
	end

	cancelFillTimer(modeId)
	pendingMatch = nil

	for _, player in roster do
		sendQueueUpdate(player)
	end
	broadcastQueueUpdates()

	GameMatchState.setBusy(true)
	for _, player in roster do
		sendQueueUpdate(player)
		Remotes.QueueUpdate:FireClient(player, {
			status = MatchmakingConfig.STATUS.Starting,
			modeId = modeId,
			modeLabel = mode.label,
			queueCount = #roster,
		})
	end

	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = roster,
	})
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	pendingMatch = nil

	for _, mode in MatchModes.all() do
		MatchmakingService.tryStartMatch(mode.id)
	end
	broadcastQueueUpdates()
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			MatchmakingService.joinRecommended(player)
			return
		end
		if modeId == "auto" then
			MatchmakingService.joinRecommended(player)
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		if pendingMatch then
			for i, pendingPlayer in pendingMatch.players do
				if pendingPlayer == player then
					table.remove(pendingMatch.players, i)
					break
				end
			end
			if #pendingMatch.players == 0 then
				pendingMatch = nil
			end
		end
		broadcastQueueUpdates()
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
