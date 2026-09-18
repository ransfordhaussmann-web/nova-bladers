local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local fillThreads = {}

local function getMode(modeId)
	return MatchModes[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function resolveModeId(modeId)
	if modeId == "auto" or modeId == nil then
		return getRecommendedModeId()
	end
	if typeof(modeId) ~= "string" or not MatchModes[modeId] then
		return nil
	end
	return modeId
end

local function getPlayerNames(playerList)
	local names = {}
	for _, player in playerList do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end
	return names
end

local function getQueueStatus(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local size = #queue

	if MatchStateService.isBusy() and size >= mode.minPlayers then
		return "pending"
	end

	if mode.fillTimeout and size >= mode.minPlayers and size < mode.maxPlayers then
		return "filling"
	end

	if size >= mode.minPlayers then
		return "ready"
	end

	return "waiting"
end

local function buildQueuePayload(player, modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local position = nil

	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		players = getPlayerNames(queue),
		status = getQueueStatus(modeId),
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function sendQueueUpdate(player, modeId)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
end

local function sendNotInQueue(player)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function broadcastQueueUpdate(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		sendQueueUpdate(player, modeId)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillThreads[modeId] = nil
end

local function removePlayerFromAllQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerQueue[player] = nil
	sendNotInQueue(player)
	broadcastQueueUpdate(modeId)

	if #queue < getMode(modeId).minPlayers then
		cancelFillTimer(modeId)
	end
end

local function popPlayersForMatch(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(matchPlayers, player)
		end
	end

	cancelFillTimer(modeId)
	broadcastQueueUpdate(modeId)
	return matchPlayers
end

local function launchMatch(modeId, matchPlayers)
	if #matchPlayers == 0 then
		return
	end

	for _, player in matchPlayers do
		HubService.enterArena(player)
		sendNotInQueue(player)
	end

	MatchReady:Fire({
		players = matchPlayers,
		modeId = modeId,
	})
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)

	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId)
		MatchStateService.whenFree(function()
			tryStartMatch(modeId)
		end)
		return
	end

	if mode.fillTimeout and #queue < mode.maxPlayers and fillThreads[modeId] then
		return
	end

	local matchPlayers = popPlayersForMatch(modeId)
	launchMatch(modeId, matchPlayers)
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode.fillTimeout then
		tryStartMatch(modeId)
		return
	end

	cancelFillTimer(modeId)
	local token = (fillTokens[modeId] or 0) + 1
	fillTokens[modeId] = token
	fillThreads[modeId] = true

	broadcastQueueUpdate(modeId)

	task.spawn(function()
		local remaining = mode.fillTimeout
		while remaining > 0 do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			remaining -= MatchmakingConfig.QUEUE_UPDATE_INTERVAL

			if fillTokens[modeId] ~= token then
				return
			end

			local queue = ensureQueue(modeId)
			if #queue < mode.minPlayers then
				return
			end

			if #queue >= mode.maxPlayers then
				break
			end

			broadcastQueueUpdate(modeId)
		end

		if fillTokens[modeId] ~= token then
			return
		end

		fillThreads[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function onQueueChanged(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)

	broadcastQueueUpdate(modeId)

	if #queue < mode.minPlayers then
		return
	end

	if #queue >= mode.maxPlayers then
		cancelFillTimer(modeId)
		tryStartMatch(modeId)
		return
	end

	if mode.fillTimeout then
		if not fillThreads[modeId] then
			startFillTimer(modeId)
		end
	else
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	local resolvedModeId = resolveModeId(modeId)
	if not resolvedModeId then
		return false
	end

	removePlayerFromAllQueues(player)

	local queue = ensureQueue(resolvedModeId)
	local mode = getMode(resolvedModeId)

	if #queue >= mode.maxPlayers then
		return false
	end

	table.insert(queue, player)
	playerQueue[player] = resolvedModeId

	onQueueChanged(resolvedModeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendNotInQueue(player)
		return
	end
	removePlayerFromAllQueues(player)
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromAllQueues(player)
	end)
end

return MatchmakingService
