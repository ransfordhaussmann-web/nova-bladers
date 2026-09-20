local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local pendingMatch = nil
local fillTokens = {}

local QueueJoin
local QueueLeave
local QueueUpdate
local MatchReady

local onMatchStart

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function isValidMode(modeId)
	return MatchModes.get(modeId) ~= nil
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
	fillTokens[entry.modeId] = (fillTokens[entry.modeId] or 0) + 1
end

local function buildUpdatePayload(player, status)
	local entry = playerEntry[player]
	if not entry then
		return {
			status = "none",
		}
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local resolvedStatus = status or entry.status or "queued"
	local message
	if resolvedStatus == "pending" then
		message = "Arena belegt — kurz warten..."
	elseif entry.modeId == "training" then
		message = "Starte Training..."
	elseif entry.modeId == "pvp" then
		message = string.format("Warte auf Gegner (%d/2)", #queue)
	elseif #queue < mode.minPlayers then
		message = string.format("Warte auf Spieler (%d/%d)", #queue, mode.minPlayers)
	else
		message = string.format("Lobby füllt sich (%d/%d)", #queue, mode.maxPlayers)
	end

	return {
		status = resolvedStatus,
		modeId = entry.modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		message = message,
	}
end

local function sendQueueUpdate(player, status)
	if not player.Parent then
		return
	end
	QueueUpdate:FireClient(player, buildUpdatePayload(player, status))
end

local function broadcastQueue(modeId)
	for _, queuedPlayer in getQueue(modeId) do
		if playerEntry[queuedPlayer] then
			sendQueueUpdate(queuedPlayer)
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchModes.getAll() do
		broadcastQueue(modeId)
	end
end

local function dequeuePlayers(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerEntry[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	MatchStateService.setBusy(true)

	if onMatchStart then
		onMatchStart(players)
	end

	MatchReady:Fire({
		players = players,
		modeId = modeId,
	})
end

local function beginMatchFromQueue(modeId, count)
	if pendingMatch then
		return
	end

	local queue = getQueue(modeId)
	if #queue < count then
		return
	end

	local players = {}
	for i = 1, count do
		players[i] = queue[i]
	end

	if MatchStateService.isBusy() then
		pendingMatch = {
			modeId = modeId,
			count = count,
		}
		for _, player in players do
			if playerEntry[player] then
				playerEntry[player].status = "pending"
				sendQueueUpdate(player, "pending")
			end
		end
		return
	end

	startMatch(modeId, dequeuePlayers(modeId, count))
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local queueSize = #queue

	if queueSize < mode.minPlayers then
		return
	end

	if mode.minPlayers == mode.maxPlayers and queueSize >= mode.maxPlayers then
		beginMatchFromQueue(modeId, mode.maxPlayers)
		return
	end

	if queueSize >= mode.maxPlayers then
		beginMatchFromQueue(modeId, mode.maxPlayers)
		return
	end

	if mode.fillTimeout and queueSize >= mode.minPlayers then
		local token = (fillTokens[modeId] or 0) + 1
		fillTokens[modeId] = token
		task.delay(mode.fillTimeout, function()
			if token ~= fillTokens[modeId] or pendingMatch then
				return
			end
			local currentQueue = getQueue(modeId)
			if #currentQueue < mode.minPlayers then
				return
			end
			local count = math.min(#currentQueue, mode.maxPlayers)
			beginMatchFromQueue(modeId, count)
		end)
		return
	end
end

local function tryStartAllModes()
	for modeId in MatchModes.getAll() do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end

	if playerEntry[player] and playerEntry[player].modeId == modeId then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player)
	playerEntry[player] = {
		modeId = modeId,
		status = "queued",
	}
	table.insert(getQueue(modeId), player)
	sendQueueUpdate(player, "queued")
	broadcastQueue(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end

	local modeId = playerEntry[player].modeId
	removeFromQueue(player)
	QueueUpdate:FireClient(player, { status = "none" })
	broadcastQueue(modeId)
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerEntry[player]
	if entry then
		return entry.modeId
	end
	return nil
end

function MatchmakingService.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)

	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		local players = dequeuePlayers(match.modeId, match.count)
		if #players > 0 then
			startMatch(match.modeId, players)
		end
		return
	end

	tryStartAllModes()
end

function MatchmakingService.init(options)
	QueueJoin = options.remotes.QueueJoin
	QueueLeave = options.remotes.QueueLeave
	QueueUpdate = options.remotes.QueueUpdate
	MatchReady = options.bindables.MatchReady
	onMatchStart = options.onMatchStart

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
