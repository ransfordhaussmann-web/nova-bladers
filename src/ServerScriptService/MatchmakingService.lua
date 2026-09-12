local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchFlowState = require(ReplicatedStorage.NovaBladers.MatchFlowState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local HubService
local queues = {}
local playerQueue = {}
local fillTokens = {}
local fillScheduled = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function countQueue(modeId)
	local queue = queues[modeId]
	return queue and #queue or 0
end

local function buildQueuePayload(player, modeId)
	local config = getModeConfig(modeId)
	local count = countQueue(modeId)
	local pending = MatchFlowState.isArenaBusy()

	local status
	if pending then
		status = "pending"
	elseif count >= config.minPlayers then
		status = "ready"
	else
		status = "waiting"
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		queued = count,
		required = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		pending = pending,
		inQueue = true,
	}
end

local function broadcastQueueUpdate(modeId)
	local count = countQueue(modeId)
	local config = getModeConfig(modeId)
	local pending = MatchFlowState.isArenaBusy()

	for _, player in Players:GetPlayers() do
		if playerQueue[player] == modeId then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end

	for _, player in Players:GetPlayers() do
		if playerQueue[player] == modeId then
			continue
		end
		if HubService and HubService.getPhase(player) == "hub" then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = modeId,
				modeLabel = config.label,
				queued = count,
				required = config.minPlayers,
				maxPlayers = config.maxPlayers,
				status = pending and "pending" or "open",
				pending = pending,
				inQueue = false,
			})
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillScheduled[modeId] = false
end

local function scheduleFillTimer(modeId)
	if fillScheduled[modeId] then
		return
	end

	local config = getModeConfig(modeId)
	if not config or not config.fillTimeout then
		return
	end

	fillScheduled[modeId] = true
	local token = fillTokens[modeId] or 0

	task.delay(config.fillTimeout, function()
		fillScheduled[modeId] = false
		if token ~= fillTokens[modeId] then
			return
		end
		if MatchFlowState.isArenaBusy() then
			broadcastQueueUpdate(modeId)
			return
		end
		if countQueue(modeId) >= config.minPlayers then
			MatchmakingService.launchMatch(modeId)
		end
	end)
end

local function setPlayerPhase(player, phase)
	if HubService and HubService.setPhase then
		HubService.setPhase(player, phase)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
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
	setPlayerPhase(player, "hub")
	broadcastQueueUpdate(modeId)

	if countQueue(modeId) < getModeConfig(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	return modeId
end

local function takePlayersForMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local takeCount = math.min(#queue, config.maxPlayers)
	local matchPlayers = {}

	for _ = 1, takeCount do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerQueue[nextPlayer] = nil
			table.insert(matchPlayers, nextPlayer)
		end
	end

	cancelFillTimer(modeId)
	broadcastQueueUpdate(modeId)

	return matchPlayers
end

function MatchmakingService.launchMatch(modeId)
	if MatchFlowState.isArenaBusy() then
		return false
	end

	local config = getModeConfig(modeId)
	if not config then
		return false
	end

	local queue = queues[modeId]
	if not queue or #queue < config.minPlayers then
		return false
	end

	local matchPlayers = takePlayersForMatch(modeId)
	if #matchPlayers < config.minPlayers then
		for _, player in matchPlayers do
			MatchmakingService.joinQueue(player, modeId)
		end
		return false
	end

	MatchFlowState.setArenaBusy(true)

	for _, player in matchPlayers do
		setPlayerPhase(player, "arena")
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			status = "starting",
			modeId = modeId,
			modeLabel = config.label,
		})
	end

	Bindables.MatchReady:Fire(matchPlayers, modeId)
	return true
end

local function tryStartMatch(modeId)
	if MatchFlowState.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not queue or #queue < config.minPlayers then
		return
	end

	if #queue >= config.maxPlayers then
		MatchmakingService.launchMatch(modeId)
		return
	end

	if config.fillTimeout then
		scheduleFillTimer(modeId)
		return
	end

	MatchmakingService.launchMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	if MatchFlowState.isArenaBusy() then
		-- Still allow joining; match starts once arena is free.
	end

	queues[modeId] = queues[modeId] or {}
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	setPlayerPhase(player, "queue")

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId then
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			status = "left",
			modeId = modeId,
		})
	end
	return modeId ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchFlowState.setArenaBusy(false)

	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.resolveModeForServer()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init(hubService)
	HubService = hubService
	Remotes, Bindables = RemotesSetup.ensure()

	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
		fillTokens[modeId] = 0
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.resolveModeForServer()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
