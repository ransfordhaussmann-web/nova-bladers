local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local HubService
local queues = {}
local playerQueue = {}
local fillTimers = {}
local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
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

	playerQueue[player] = nil
end

local function buildQueuePayload(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	local status = "waiting"
	if GameMatchState.isArenaBusy() then
		status = "pending"
	elseif mode and #queue >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = MatchmakingConfig.getModeLabel(modeId),
		players = names,
		count = #names,
		needed = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
		inQueue = player ~= nil and playerQueue[player] ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId)
	for _, queuedPlayer in getQueue(modeId) do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueueUpdate(modeId)
	end
end

local function cancelFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or mode.startImmediately or not mode.fillTimeout then
		return
	end

	cancelFillTimer(modeId)
	local token = {}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function markPlayersArena(players)
	for _, player in players do
		if HubService and HubService.getPhase(player) == "hub" then
			HubService.leaveHubForArena(player)
		end
	end
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	local readyPlayers = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent and HubService and HubService.getPhase(queuedPlayer) == "hub" then
			table.insert(readyPlayers, queuedPlayer)
		end
	end

	if #readyPlayers < mode.minPlayers then
		return false
	end

	if #readyPlayers > mode.maxPlayers then
		local trimmed = {}
		for i = 1, mode.maxPlayers do
			trimmed[i] = readyPlayers[i]
		end
		readyPlayers = trimmed
	end

	if GameMatchState.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return false
	end

	cancelFillTimer(modeId)

	for _, player in readyPlayers do
		removeFromQueue(player)
	end

	markPlayersArena(readyPlayers)
	Bindables.MatchReady:Fire(readyPlayers, modeId)
	broadcastAllQueues()
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end

	if HubService and HubService.getPhase(player) ~= "hub" then
		return false
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false
	end

	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }

	broadcastQueueUpdate(modeId)

	if mode.startImmediately and #queue >= mode.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif not mode.startImmediately and #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif not mode.startImmediately and #queue >= mode.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	if mode and not mode.startImmediately and #queue < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.onArenaFreed()
	for modeId in MatchmakingConfig.MODES do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.getPlayerQueue(player)
	local entry = playerQueue[player]
	return entry and entry.modeId or nil
end

function MatchmakingService.start(hubHandlers)
	HubService = hubHandlers
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

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
