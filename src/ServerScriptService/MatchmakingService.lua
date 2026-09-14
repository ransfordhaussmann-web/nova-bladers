local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerEntry = {}
local pendingMatches = {}
local fillTimers = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function isValidPlayer(player)
	return player and player.Parent and HubService.getPhase(player) ~= "arena"
end

local function getModeLabel(modeId)
	local mode = MatchModes.get(modeId)
	return mode and mode.label or modeId
end

local function buildQueuePayload(player, modeId, status)
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
		modeLabel = getModeLabel(modeId),
		status = status,
		position = position,
		total = #queue,
		minPlayers = MatchModes.get(modeId).minPlayers,
		maxPlayers = MatchModes.get(modeId).maxPlayers,
	}
end

local function sendQueueUpdate(player, modeId, status)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
	end
end

local function broadcastQueueMode(modeId)
	local queue = getQueue(modeId)
	for i, player in queue do
		sendQueueUpdate(player, modeId, "queued")
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function removePendingPlayer(player)
	for i = #pendingMatches, 1, -1 do
		local match = pendingMatches[i]
		for j, queuedPlayer in match.players do
			if queuedPlayer == player then
				table.remove(match.players, j)
				break
			end
		end
		local mode = MatchModes.get(match.modeId)
		if not mode or #match.players < mode.minPlayers then
			table.remove(pendingMatches, i)
		end
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
	broadcastQueueMode(modeId)

	if #queue < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local ready = {}

	for _, player in queue do
		if isValidPlayer(player) then
			table.insert(ready, player)
		end
		if #ready >= mode.maxPlayers then
			break
		end
	end

	if #ready < mode.minPlayers then
		return nil
	end

	return ready
end

local function dequeuePlayers(players, modeId)
	local queue = getQueue(modeId)
	local removeSet = {}
	for _, player in players do
		removeSet[player] = true
		playerEntry[player] = nil
	end

	for i = #queue, 1, -1 do
		if removeSet[queue[i]] then
			table.remove(queue, i)
		end
	end

	clearFillTimer(modeId)
	broadcastQueueMode(modeId)
end

local function launchMatch(modeId, players)
	for _, player in players do
		playerEntry[player] = nil
		HubService.setPhase(player, "arena")
	end

	GameMatchState.setArenaBusy(true)
	Bindables.MatchReady:Fire(players, modeId)
end

local function tryLaunchMatch(modeId)
	local players = collectReadyPlayers(modeId)
	if not players then
		return false
	end

	dequeuePlayers(players, modeId)

	if GameMatchState.isArenaBusy() then
		for _, player in players do
			playerEntry[player] = { modeId = modeId, status = "pending" }
			sendQueueUpdate(player, modeId, "pending")
		end
		table.insert(pendingMatches, {
			modeId = modeId,
			players = players,
		})
		return true
	end

	launchMatch(modeId, players)
	return true
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	local token = {}
	fillTimers[modeId] = token
	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryLaunchMatch(modeId)
	end)
end

local function onQueueChanged(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if #queue >= mode.maxPlayers then
		tryLaunchMatch(modeId)
		return
	end

	if #queue >= mode.minPlayers then
		if mode.fillTimeout then
			startFillTimer(modeId)
		else
			tryLaunchMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerEntry[player] then
		MatchmakingService.leaveQueue(player)
	end

	if HubService.getPhase(player) ~= "queue" then
		HubService.setPhase(player, "queue")
	end

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerEntry[player] = { modeId = modeId }

	sendQueueUpdate(player, modeId, "queued")
	broadcastQueueMode(modeId)
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	removePendingPlayer(player)
	removeFromQueue(player)

	if player.Parent and HubService.getPhase(player) == "queue" then
		HubService.setPhase(player, "hub")
		Remotes.QueueUpdate:FireClient(player, { status = "left" })
	end
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaBusy(false)

	while #pendingMatches > 0 and not GameMatchState.isArenaBusy() do
		local nextMatch = table.remove(pendingMatches, 1)
		local validPlayers = {}
		for _, player in nextMatch.players do
			if isValidPlayer(player) then
				table.insert(validPlayers, player)
			end
		end

		local mode = MatchModes.get(nextMatch.modeId)
		if mode and #validPlayers >= mode.minPlayers then
			launchMatch(nextMatch.modeId, validPlayers)
		end
	end
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
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

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
