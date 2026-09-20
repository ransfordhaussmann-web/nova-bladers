local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local HubService

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function modeLabel(modeId)
	local mode = MatchModes.get(modeId)
	return mode and mode.label or modeId
end

local function buildQueuePayload(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local names = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId)
	if not payload then
		return
	end

	for _, player in queues[modeId] do
		if player.Parent then
			local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				status = status,
				queue = payload,
			})
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	broadcastQueue(modeId)
end

local function notifyLeftQueue(player)
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = false,
	})
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local ready = {}

	for i = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[i]
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(ready, player)
		end
	end

	return ready, mode
end

local function removePlayersFromQueue(modeId, playerList)
	local removeSet = {}
	for _, player in playerList do
		removeSet[player] = true
		playerQueue[player] = nil
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if removeSet[queue[i]] then
			table.remove(queue, i)
		end
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	broadcastQueue(modeId)
end

local function markPlayersArena(playerList)
	for _, player in playerList do
		if player.Parent then
			playerQueue[player] = nil
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
end

local function launchMatch(modeId, playerList)
	removePlayersFromQueue(modeId, playerList)
	markPlayersArena(playerList)
	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local ready, mode = collectReadyPlayers(modeId)
	if #ready < mode.minPlayers then
		return false
	end

	if mode.startImmediately or #ready >= mode.maxPlayers then
		launchMatch(modeId, ready)
		return true
	end

	if mode.fillTimeout and not fillTimers[modeId] and #ready >= mode.minPlayers then
		fillTimers[modeId] = task.delay(mode.fillTimeout, function()
			fillTimers[modeId] = nil
			if MatchStateService.isArenaBusy() then
				return
			end
			local readyPlayers, readyMode = collectReadyPlayers(modeId)
			if #readyPlayers >= readyMode.minPlayers then
				launchMatch(modeId, readyPlayers)
			end
		end)
	end

	return false
end

local function processPendingMatch()
	if not pendingMatch or MatchStateService.isArenaBusy() then
		return
	end

	local snapshot = pendingMatch
	pendingMatch = nil
	launchMatch(snapshot.modeId, snapshot.players)
end

local function queueMatchWhenReady(modeId, playerList)
	if MatchStateService.isArenaBusy() then
		removePlayersFromQueue(modeId, playerList)
		pendingMatch = {
			modeId = modeId,
			players = playerList,
		}
		for _, player in playerList do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					inQueue = true,
					status = "pending",
					queue = buildQueuePayload(modeId),
				})
			end
		end
		return
	end

	launchMatch(modeId, playerList)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	broadcastQueue(modeId)

	local mode = MatchModes.get(modeId)
	local ready = collectReadyPlayers(modeId)
	if #ready >= mode.minPlayers and (mode.startImmediately or #ready >= mode.maxPlayers) then
		if MatchStateService.isArenaBusy() then
			queueMatchWhenReady(modeId, ready)
		else
			tryStartMatch(modeId)
		end
	elseif mode.fillTimeout and #ready >= mode.minPlayers then
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	clearPlayerFromQueues(player)
	notifyLeftQueue(player)

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

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(hubServiceRef)
	HubService = hubServiceRef
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onMatchEnded(function()
		task.defer(function()
			processPendingMatch()
			for modeId in queues do
				tryStartMatch(modeId)
			end
			broadcastAllQueues()
		end)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
