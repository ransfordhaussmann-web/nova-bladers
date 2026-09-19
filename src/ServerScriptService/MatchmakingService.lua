local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables
local callbacks = {}
local queues = {}
local playerQueue = {}
local pendingMatch = nil
local fillTimers = {}

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromAllQueues(player)
	local previousMode = playerQueue[player]
	if not previousMode then
		return nil
	end

	local queue = ensureQueue(previousMode)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	playerQueue[player] = nil
	return previousMode
end

local function cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function isPlayerPending(player)
	if not pendingMatch then
		return false
	end
	for _, queuedPlayer in pendingMatch.players do
		if queuedPlayer == player then
			return true
		end
	end
	return false
end

local function getQueueStatus(modeId, queue)
	local mode = getMode(modeId)
	if not mode then
		return "waiting", ""
	end

	if pendingMatch and pendingMatch.modeId == modeId then
		return "pending", "Arena belegt — Warte auf freien Slot..."
	end

	if MatchStateService.isArenaBusy() then
		return "pending", "Arena belegt — Warte auf freien Slot..."
	end

	if #queue >= mode.maxPlayers then
		return "starting", "Match startet gleich..."
	end

	if mode.id == "ffa" and #queue >= mode.minPlayers and fillTimers[modeId] then
		return "waiting", string.format("Warte auf Spieler (%d/%d)...", #queue, mode.maxPlayers)
	end

	if #queue >= mode.minPlayers then
		return "starting", "Match startet gleich..."
	end

	return "waiting", string.format("Warte auf Spieler (%d/%d)...", #queue, mode.minPlayers)
end

local function buildQueuePayload(player)
	if isPlayerPending(player) then
		local mode = getMode(pendingMatch.modeId)
		return {
			inQueue = true,
			modeId = pendingMatch.modeId,
			modeLabel = mode.label,
			queued = #pendingMatch.players,
			needed = mode.minPlayers,
			max = mode.maxPlayers,
			status = "pending",
			statusText = "Arena belegt — Warte auf freien Slot...",
		}
	end

	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local status, statusText = getQueueStatus(modeId, queue)

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queued = #queue,
		needed = mode.minPlayers,
		max = mode.maxPlayers,
		status = status,
		statusText = statusText,
	}
end

local function sendQueueUpdate(player)
	if player.Parent and Remotes.QueueUpdate then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueForMode(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		sendQueueUpdate(player)
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueForMode(modeId)
	end
end

local function collectReadyPlayers(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local players = {}

	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(players, queue[i])
	end

	return players
end

local function detachPlayersFromQueue(players)
	for _, player in players do
		removeFromAllQueues(player)
	end
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	pendingMatch = nil

	for _, player in players do
		if callbacks.onMatchStarting then
			callbacks.onMatchStarting(player, modeId)
		end
		sendQueueUpdate(player)
	end

	broadcastAllQueues()
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = players,
	})
end

local function scheduleFfaFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or mode.id ~= "ffa" or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers[modeId] = nil
		local queue = ensureQueue(modeId)
		if #queue >= mode.minPlayers then
			queueMatchWhenReady(modeId)
		else
			broadcastQueueForMode(modeId)
		end
	end)
end

local function queueMatchWhenReady(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	if not mode or #queue < mode.minPlayers then
		return
	end

	local players = collectReadyPlayers(modeId)
	if #players == 0 then
		return
	end

	if MatchStateService.isArenaBusy() or pendingMatch then
		pendingMatch = {
			modeId = modeId,
			players = players,
		}
		for _, player in players do
			sendQueueUpdate(player)
		end
		return
	end

	cancelFillTimer(modeId)
	detachPlayersFromQueue(players)
	launchMatch(modeId, players)
end

local function evaluateMode(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	if not mode or #queue < mode.minPlayers then
		cancelFillTimer(modeId)
		return
	end

	if #queue >= mode.maxPlayers then
		queueMatchWhenReady(modeId)
		return
	end

	if mode.id == "ffa" then
		if not fillTimers[modeId] then
			scheduleFfaFillTimer(modeId)
		end
		return
	end

	if #queue >= mode.minPlayers then
		queueMatchWhenReady(modeId)
	end
end

local function joinQueue(player, modeId)
	if not getMode(modeId) then
		return
	end

	if callbacks.getPhase and callbacks.getPhase(player) ~= "hub" then
		return
	end

	removeFromAllQueues(player)
	table.insert(ensureQueue(modeId), player)
	playerQueue[player] = modeId

	broadcastQueueForMode(modeId)
	evaluateMode(modeId)
end

local function leaveQueue(player)
	local modeId = removeFromAllQueues(player)
	if modeId then
		cancelFillTimer(modeId)
		sendQueueUpdate(player)
		broadcastQueueForMode(modeId)
		evaluateMode(modeId)
	end
end

local function onMatchEnded()
	MatchStateService.setArenaBusy(false)

	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		detachPlayersFromQueue(match.players)
		launchMatch(match.modeId, match.players)
		return
	end

	for modeId in queues do
		evaluateMode(modeId)
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

function MatchmakingService.init(options)
	callbacks = options or {}
	Remotes, Bindables = RemotesSetup.ensure()

	for _, mode in MatchModes.all() do
		ensureQueue(mode.id)
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			modeId = resolveQuickMatchMode()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(onMatchEnded)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.getQuickMatchMode()
	return resolveQuickMatchMode()
end

return MatchmakingService
