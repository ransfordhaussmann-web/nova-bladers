local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function initQueues()
	for modeId in MatchModes do
		if typeof(MatchModes[modeId]) == "table" and MatchModes[modeId].id then
			queues[modeId] = {}
		end
	end
end

local function getQueueCount(modeId)
	return #(queues[modeId] or {})
end

local function buildStatusText(mode, count, pending)
	if pending then
		return "Arena belegt — warte..."
	end
	if count < mode.minPlayers then
		return string.format("Warte auf Spieler (%d/%d)", count, mode.minPlayers)
	end
	if mode.fillTimeout and count < mode.maxPlayers then
		return string.format("Spieler gefunden (%d/%d) — Füllphase", count, mode.maxPlayers)
	end
	return string.format("Match startet (%d Spieler)", count)
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	local count = #queue
	local pending = MatchStateService.isArenaBusy() and count >= mode.minPlayers

	for i, queuedPlayer in queue do
		sendQueueUpdate(queuedPlayer, {
			inQueue = true,
			modeId = modeId,
			modeLabel = mode.label,
			position = i,
			needed = mode.minPlayers,
			current = count,
			maxPlayers = mode.maxPlayers,
			pending = pending,
			statusText = buildStatusText(mode, count, pending),
		})
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	sendQueueUpdate(player, { inQueue = false })
	broadcastQueueUpdates(modeId)

	local mode = MatchModes.get(modeId)
	if mode and getQueueCount(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
	end
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
			sendQueueUpdate(player, { inQueue = false })
		end
	end
	broadcastQueueUpdates(modeId)
	return taken
end

local function leaveHubForMatch(players)
	for _, player in players do
		if HubService.getPhase(player) ~= "arena" then
			HubService.leaveHubForArena(player)
		end
	end
end

local function launchMatch(modeId, players)
	clearFillTimer(modeId)
	leaveHubForMatch(players)
	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return
	end

	if mode.fillTimeout and count < mode.maxPlayers then
		if not fillTimers[modeId] then
			broadcastQueueUpdates(modeId)
			local token = { cancelled = false }
			fillTimers[modeId] = token
			task.delay(mode.fillTimeout, function()
				if token.cancelled or fillTimers[modeId] ~= token then
					return
				end
				fillTimers[modeId] = nil
				if getQueueCount(modeId) >= mode.minPlayers and not MatchStateService.isArenaBusy() then
					local players = takePlayers(modeId, mode.maxPlayers)
					if #players >= mode.minPlayers then
						launchMatch(modeId, players)
					end
				end
			end)
		end
		return
	end

	clearFillTimer(modeId)
	local players = takePlayers(modeId, mode.maxPlayers)
	if #players >= mode.minPlayers then
		launchMatch(modeId, players)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchModes.getRecommended(#Players:GetPlayers())
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if HubService.getPhase(player) == "arena" then
		return false
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdates(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFree()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		MatchmakingService.onArenaFree()
	end)
end

return MatchmakingService
