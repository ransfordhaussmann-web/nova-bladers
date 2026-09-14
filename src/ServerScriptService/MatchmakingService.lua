local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local matchReadyEvent
local onPlayersEnterArena

local queues = {}
local playerQueue = {}
local fillTimers = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {}, pending = false }
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
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue.players == 0 then
		queue.pending = false
		if fillTimers[modeId] then
			task.cancel(fillTimers[modeId])
			fillTimers[modeId] = nil
		end
	end
end

local function buildStatusText(mode, queue, status)
	local count = #queue.players
	if status == "pending" then
		return "Arena belegt — Warteschlange pausiert"
	end
	if status == "starting" then
		return "Match startet..."
	end
	if mode.instant or count >= mode.minPlayers then
		return string.format("Bereit (%d/%d)", count, mode.maxPlayers)
	end
	return string.format("Warte auf Spieler (%d/%d)", count, mode.minPlayers)
end

local function buildQueuePayload(player, modeId, status)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players
	local position = 1
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		total = count,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		statusText = buildStatusText(mode, queue, status),
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent and remotes.QueueUpdate then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId, status)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		sendQueueUpdate(player, buildQueuePayload(player, modeId, status))
	end
end

local function clearQueueUpdate(player)
	sendQueueUpdate(player, { inQueue = false })
end

local function cancelFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMode(modeId)
	end)
end

local function takePlayers(modeId)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)
	local taken = {}
	local limit = math.min(#queue.players, mode.maxPlayers)

	for i = 1, limit do
		table.insert(taken, queue.players[i])
	end

	for i = 1, limit do
		table.remove(queue.players, 1)
	end

	for _, player in taken do
		playerQueue[player] = nil
		clearQueueUpdate(player)
	end

	if #queue.players == 0 then
		queue.pending = false
		cancelFillTimer(modeId)
	end

	return taken
end

function MatchmakingService.tryStartMode(modeId)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)

	if #queue.players < mode.minPlayers then
		return false
	end

	if MatchStateService.isArenaBusy() then
		queue.pending = true
		broadcastQueue(modeId, "pending")
		return false
	end

	local players = takePlayers(modeId)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return false
	end

	cancelFillTimer(modeId)
	queue.pending = false

	for _, player in players do
		sendQueueUpdate(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = mode.label,
			status = "starting",
			statusText = "Match startet...",
		})
	end

	if onPlayersEnterArena then
		for _, player in players do
			onPlayersEnterArena(player)
		end
	end

	matchReadyEvent:Fire({
		modeId = modeId,
		players = players,
	})

	return true
end

local function evaluateQueue(modeId)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)

	if #queue.players == 0 then
		return
	end

	if mode.instant and #queue.players >= 1 then
		MatchmakingService.tryStartMode(modeId)
		return
	end

	if #queue.players >= mode.maxPlayers then
		MatchmakingService.tryStartMode(modeId)
		return
	end

	if #queue.players >= mode.minPlayers then
		if mode.fillTimeout then
			startFillTimer(modeId)
			broadcastQueue(modeId, "waiting")
		else
			MatchmakingService.tryStartMode(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return
	end

	modeId = modeId or MatchModes.getRecommended(#Players:GetPlayers()).id
	if not MatchModes.get(modeId) then
		return
	end

	if playerQueue[player] == modeId then
		return
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId).players, player)
	playerQueue[player] = modeId

	local queue = getQueue(modeId)
	local status = "waiting"
	if #queue.players >= getMode(modeId).minPlayers and MatchStateService.isArenaBusy() then
		status = "pending"
	end
	broadcastQueue(modeId, status)
	evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	clearQueueUpdate(player)

	if modeId then
		local queue = getQueue(modeId)
		local status = "waiting"
		if #queue.players >= getMode(modeId).minPlayers and MatchStateService.isArenaBusy() then
			status = "pending"
		end
		broadcastQueue(modeId, status)
	end
end

function MatchmakingService.onArenaFreed()
	for modeId, _ in queues do
		local queue = getQueue(modeId)
		if queue.pending and #queue.players >= getMode(modeId).minPlayers then
			queue.pending = false
			MatchmakingService.tryStartMode(modeId)
		elseif #queue.players > 0 then
			broadcastQueue(modeId, "waiting")
			evaluateQueue(modeId)
		end
	end
end

function MatchmakingService.start(remoteFolder, bindables, enterArenaCallback)
	remotes = remoteFolder
	matchReadyEvent = bindables.MatchReady
	onPlayersEnterArena = enterArenaCallback

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.getRecommended(#Players:GetPlayers()).id
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
