local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local fillTimers = {}
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
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

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(modeId, player)
	local mode = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	local payload = {
		modeId = modeId,
		modeLabel = mode.label,
		queued = #names,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		playerNames = names,
		inQueue = playerQueue[player] == modeId,
		pendingArena = pendingMatch ~= nil and pendingMatch.modeId == modeId,
	}

	if playerQueue[player] == modeId then
		payload.status = pendingMatch and pendingMatch.modeId == modeId
			and "Warte auf freie Arena..."
			or string.format("In Warteschlange (%d/%d)", #names, mode.minPlayers)
	end

	return payload
end

local function broadcastQueueUpdate(modeId)
	local queue = ensureQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local mode = getModeConfig(modeId)
	if not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function markPlayersArena(playerList)
	for _, player in playerList do
		removeFromQueue(player)
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		if callbacks.onPlayerEnterArena then
			callbacks.onPlayerEnterArena(player)
		end
	end
end

local function consumePendingMatch()
	if not pendingMatch then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	clearFillTimer(match.modeId)
	queues[match.modeId] = {}

	for _, player in match.players do
		playerQueue[player] = nil
	end

	markPlayersArena(match.players)
	Bindables.MatchReady:Fire(match.players)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return false
	end

	local queue = ensureQueue(modeId)
	local readyPlayers = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent and #readyPlayers < mode.maxPlayers then
			table.insert(readyPlayers, queuedPlayer)
		end
	end

	if #readyPlayers < mode.minPlayers then
		return false
	end

	clearFillTimer(modeId)

	if GameMatchState.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = readyPlayers,
		}
		queues[modeId] = {}
		broadcastQueueUpdate(modeId)
		return true
	end

	queues[modeId] = {}
	for _, player in readyPlayers do
		playerQueue[player] = nil
	end

	markPlayersArena(readyPlayers)
	Bindables.MatchReady:Fire(readyPlayers)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return false, "Unbekannter Modus"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	local queue = ensureQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer == player then
			return true
		end
	end

	if #queue >= mode.maxPlayers then
		return false, "Warteschlange voll"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)

	if #queue >= mode.minPlayers then
		if mode.fillTimeout and #queue < mode.maxPlayers then
			startFillTimer(modeId)
		else
			MatchmakingService.tryStartMatch(modeId)
		end
	elseif mode.fillTimeout then
		startFillTimer(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)

	if pendingMatch and pendingMatch.modeId == modeId then
		local stillQueued = {}
		for _, queuedPlayer in pendingMatch.players do
			if queuedPlayer ~= player and queuedPlayer.Parent and playerQueue[queuedPlayer] == modeId then
				table.insert(stillQueued, queuedPlayer)
			end
		end
		if #stillQueued < getModeConfig(modeId).minPlayers then
			pendingMatch = nil
		else
			pendingMatch.players = stillQueued
		end
	end

	broadcastQueueUpdate(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaBusy(false)
	consumePendingMatch()
end

function MatchmakingService.onMatchStarted()
	GameMatchState.setArenaBusy(true)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start(hubCallbacks)
	callbacks = hubCallbacks or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingConfig.DEFAULT_MODE
		end
		local ok, err = MatchmakingService.joinQueue(player, modeId)
		if not ok and err then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false, error = err })
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
