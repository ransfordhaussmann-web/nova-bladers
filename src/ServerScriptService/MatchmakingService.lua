local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchGate = require(script.Parent.MatchGate)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatches = {}
local readyTokens = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
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
	readyTokens[player] = nil
end

local function buildQueuePayload(modeId, player)
	local queue = queues[modeId]
	local mode = getModeConfig(modeId)
	local position = 0

	for i, queuedPlayer in queue do
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
		queued = #queue,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}
end

local function buildIdlePayload()
	return {
		inQueue = false,
		modeId = nil,
		modeLabel = nil,
		position = 0,
		queued = 0,
		required = 0,
		maxPlayers = 0,
	}
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end

	local modeId = playerQueue[player]
	if modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	else
		Remotes.QueueUpdate:FireClient(player, buildIdlePayload())
	end
end

local function broadcastQueue(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendQueueUpdate(queuedPlayer)
	end
end

local function startMatch(playerList, modeId)
	for _, player in playerList do
		readyTokens[player] = nil
		HubService.leaveHubForArena(player)
	end

	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartPending()
	if not MatchGate.isAvailable() or #pendingMatches == 0 then
		return
	end

	local nextMatch = table.remove(pendingMatches, 1)
	startMatch(nextMatch.players, nextMatch.modeId)
end

local function enqueuePending(playerList, modeId)
	table.insert(pendingMatches, {
		players = playerList,
		modeId = modeId,
	})
end

local function tryLaunchMode(modeId)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	local playerList = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(playerList, queue[i])
	end

	for _, player in playerList do
		removeFromQueue(player)
		readyTokens[player] = (readyTokens[player] or 0) + 1
	end
	broadcastQueue(modeId)

	local token = readyTokens[playerList[1]]
	task.delay(MatchmakingConfig.MATCH_READY_DELAY, function()
		local validPlayers = {}
		for _, player in playerList do
			if player.Parent and readyTokens[player] == token then
				table.insert(validPlayers, player)
			end
		end

		if #validPlayers < mode.minPlayers then
			for _, player in validPlayers do
				MatchmakingService.joinQueue(player, modeId)
			end
			return
		end

		if MatchGate.isAvailable() then
			startMatch(validPlayers, modeId)
		else
			enqueuePending(validPlayers, modeId)
		end

		tryLaunchMode(modeId)
	end)
end

function MatchmakingService.getAutoModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryLaunchMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player)
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	broadcastQueue(modeId)
	sendQueueUpdate(player)
end

function MatchmakingService.onArenaFreed()
	tryStartPending()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.getQueueSize(modeId)
	return #(queues[modeId] or {})
end

return MatchmakingService
