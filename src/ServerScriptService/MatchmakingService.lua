local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables = RemotesSetup.ensure()

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local ffaTimers = {}
local started = false

local function initQueues()
	for _, modeId in MatchModes.all() do
		queues[modeId] = {}
	end
end

local function getQueueCount(modeId)
	return #(queues[modeId] or {})
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId] or {}
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if pendingMatch and pendingMatch.modeId == modeId then
		local inPending = false
		for _, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				inPending = true
				break
			end
		end
		if inPending then
			status = GameMatchState.isArenaBusy() and "pending" or "ready"
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = position > 0,
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for _, modeId in MatchModes.all() do
		broadcastQueue(modeId)
	end
end

local function clearFfaTimer(modeId)
	local token = ffaTimers[modeId]
	if token then
		ffaTimers[modeId] = nil
	end
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
	broadcastQueue(modeId)

	if pendingMatch then
		local stillPending = false
		for i, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				table.remove(pendingMatch.players, i)
			elseif pendingPlayer.Parent then
				stillPending = true
			end
		end
		if not stillPending then
			pendingMatch = nil
		elseif #pendingMatch.players < MatchModes.get(pendingMatch.modeId).minPlayers then
			pendingMatch = nil
		end
	end

	if modeId == "ffa" and getQueueCount("ffa") < MatchModes.get("ffa").minPlayers then
		clearFfaTimer("ffa")
	end
end

local function leaveHubForArena(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	if HubService.leaveHubForArena then
		HubService.leaveHubForArena(player)
	end
end

local function launchMatch(modeId, playerList)
	pendingMatch = nil
	clearFfaTimer(modeId)

	for _, player in playerList do
		removeFromQueue(player)
		leaveHubForArena(player)
	end

	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = playerList,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	if not queue or #queue < mode.minPlayers then
		return
	end

	if GameMatchState.isArenaBusy() then
		if not pendingMatch or pendingMatch.modeId ~= modeId then
			local roster = {}
			for i = 1, math.min(#queue, mode.maxPlayers) do
				table.insert(roster, queue[i])
			end
			pendingMatch = {
				modeId = modeId,
				players = roster,
			}
		end
		broadcastQueue(modeId)
		return
	end

	local roster = {}
	if pendingMatch and pendingMatch.modeId == modeId then
		for _, player in pendingMatch.players do
			if player.Parent then
				table.insert(roster, player)
			end
		end
		pendingMatch = nil
	else
		for i = 1, math.min(#queue, mode.maxPlayers) do
			table.insert(roster, queue[i])
		end
	end

	if #roster < mode.minPlayers then
		return
	end

	launchMatch(modeId, roster)
end

local function scheduleFfaFillTimer()
	if ffaTimers.ffa then
		return
	end

	local token = {}
	ffaTimers.ffa = token

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if ffaTimers.ffa ~= token then
			return
		end
		ffaTimers.ffa = nil
		tryStartMatch("ffa")
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		return false
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)

	local mode = MatchModes.get(modeId)
	if #queues[modeId] >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif modeId == "training" then
		tryStartMatch(modeId)
	elseif modeId == "ffa" and #queues[modeId] >= mode.minPlayers then
		scheduleFfaFillTimer()
	elseif modeId == "pvp" and #queues[modeId] >= mode.minPlayers then
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "idle" })
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true
	initQueues()

	GameMatchState.onArenaFree(function()
		for _, modeId in MatchModes.all() do
			tryStartMatch(modeId)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastAllQueues()
		end
	end)
end

return MatchmakingService
