local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerMode = {}
local fillTokens = {}
local pendingMatch = nil

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
		fillTokens[modeId] = 0
	end
end

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function getModeLabel(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	return mode and mode.label or modeId
end

local function buildQueuePayload(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	local count = getQueueCount(modeId)
	local status = "waiting"

	if pendingMatch and pendingMatch.modeId == modeId then
		for _, queuedPlayer in pendingMatch.players do
			if queuedPlayer == player then
				status = "pending"
				break
			end
		end
	end

	return {
		modeId = modeId,
		modeLabel = getModeLabel(modeId),
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		inQueue = true,
		status = status,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = {
		modeId = modeId,
		modeLabel = getModeLabel(modeId),
		count = getQueueCount(modeId),
		minPlayers = MatchmakingConfig.getMode(modeId).minPlayers,
		maxPlayers = MatchmakingConfig.getMode(modeId).maxPlayers,
	}

	for _, player in queues[modeId] do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearPlayerFromQueues(player)
	local previousMode = playerMode[player]
	if not previousMode then
		return
	end

	playerMode[player] = nil
	local queue = queues[previousMode]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	broadcastQueueUpdate(previousMode)
end

local function removePlayersFromQueue(modeId, playerList)
	local queue = queues[modeId]
	for _, matchPlayer in playerList do
		playerMode[matchPlayer] = nil
		for i = #queue, 1, -1 do
			if queue[i] == matchPlayer then
				table.remove(queue, i)
			end
		end
	end
	broadcastQueueUpdate(modeId)
end

local function canStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local count = getQueueCount(modeId)
	return count >= mode.minPlayers
end

local function collectMatchPlayers(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	local playerList = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(playerList, queue[i])
	end
	return playerList
end

local function notifyQueueLeft(player)
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = false,
	})
end

local function startMatchNow(modeId, playerList)
	removePlayersFromQueue(modeId, playerList)

	for _, player in playerList do
		if player.Parent and HubService.getPhase(player) == "hub" then
			HubService.leaveHubForArena(player)
		end
	end

	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryLaunchMatch(modeId)
	if not canStartMatch(modeId) then
		return
	end

	local playerList = collectMatchPlayers(modeId)
	if #playerList == 0 then
		return
	end

	if GameMatchState.isBusy() or pendingMatch then
		pendingMatch = {
			modeId = modeId,
			players = playerList,
		}
		for _, player in playerList do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
			end
		end
		return
	end

	pendingMatch = nil
	startMatchNow(modeId, playerList)
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] += 1
end

local function scheduleFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	cancelFillTimer(modeId)
	fillTokens[modeId] += 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if getQueueCount(modeId) >= mode.minPlayers then
			tryLaunchMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.getMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	clearPlayerFromQueues(player)

	local queue = queues[modeId]
	table.insert(queue, player)
	playerMode[player] = modeId

	local mode = MatchmakingConfig.getMode(modeId)
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)

	if getQueueCount(modeId) >= mode.maxPlayers then
		cancelFillTimer(modeId)
		tryLaunchMatch(modeId)
		return
	end

	if getQueueCount(modeId) == 1 and mode.fillTimeout > 0 then
		scheduleFillTimer(modeId)
	end

	if canStartMatch(modeId) and (mode.fillTimeout <= 0 or modeId == "pvp") then
		tryLaunchMatch(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	local modeId = playerMode[player]
	clearPlayerFromQueues(player)
	notifyQueueLeft(player)

	if getQueueCount(modeId) == 0 then
		cancelFillTimer(modeId)
	end

	if pendingMatch then
		for i, matchPlayer in pendingMatch.players do
			if matchPlayer == player then
				table.remove(pendingMatch.players, i)
				break
			end
		end
		local pendingMode = MatchmakingConfig.getMode(pendingMatch.modeId)
		if #pendingMatch.players < pendingMode.minPlayers then
			pendingMatch = nil
		end
	end
end

function MatchmakingService.onArenaFree()
	if pendingMatch and not GameMatchState.isBusy() then
		local match = pendingMatch
		pendingMatch = nil
		startMatchNow(match.modeId, match.players)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		if pendingMatch then
			for i, matchPlayer in pendingMatch.players do
				if matchPlayer == player then
					table.remove(pendingMatch.players, i)
					break
				end
			end
			if #pendingMatch.players == 0 then
				pendingMatch = nil
			end
		end
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
