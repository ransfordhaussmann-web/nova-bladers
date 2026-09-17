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
local initialized = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end
	return queues[modeId]
end

local function isPlayerValid(player)
	return player and player.Parent and HubService.getPhase(player) == "hub"
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local kept = {}
	for _, player in queue.players do
		if isPlayerValid(player) then
			table.insert(kept, player)
		else
			playerQueue[player] = nil
		end
	end
	queue.players = kept
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	pruneQueue(modeId)

	local names = {}
	for _, queuedPlayer in queue.players do
		table.insert(names, queuedPlayer.DisplayName)
	end

	local pending = MatchStateService.isArenaBusy()
	local status = "waiting"
	if pending then
		status = "pending"
	elseif #queue.players >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		pending = pending,
		fillTimeout = queue.fillDeadline and math.max(0, math.ceil(queue.fillDeadline - os.clock())) or nil,
		inQueue = player ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	pruneQueue(modeId)
	local queue = getQueue(modeId)
	local seen = {}

	for _, player in queue.players do
		seen[player] = true
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end

	for queuedPlayer, queuedModeId in playerQueue do
		if queuedModeId == modeId and not seen[queuedPlayer] and queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local queue = getQueue(modeId)
	queue.fillDeadline = nil
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	local queue = getQueue(modeId)
	if queue.fillDeadline then
		return
	end

	queue.fillDeadline = os.clock() + mode.fillTimeout
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		queue.fillDeadline = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end

	local mode = MatchModes.get(modeId)
	if #queue.players < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end
	if not isPlayerValid(player) then
		return
	end
	if MatchmakingService.isInQueue(player) then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	if #queue.players >= mode.minPlayers and mode.fillTimeout > 0 and #queue.players < mode.maxPlayers then
		startFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	pruneQueue(modeId)

	if #queue.players < mode.minPlayers then
		return
	end

	local canStart = #queue.players >= mode.maxPlayers
	if not canStart and mode.fillTimeout > 0 then
		canStart = queue.fillDeadline ~= nil and os.clock() >= queue.fillDeadline
	elseif not canStart and mode.fillTimeout <= 0 then
		canStart = #queue.players >= mode.minPlayers
	end

	if not canStart then
		broadcastQueueUpdate(modeId)
		return
	end

	local matchPlayers = {}
	for index = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(matchPlayers, queue.players[index])
	end

	for _, player in matchPlayers do
		MatchmakingService.leaveQueue(player)
		HubService.leaveHubForArena(player)
	end

	cancelFillTimer(modeId)
	MatchReady:Fire(matchPlayers, modeId)
end

function MatchmakingService.onArenaFree()
	for _, modeId in MatchModes.all() do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

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

	MatchStateService.onArenaFree(function()
		MatchmakingService.onArenaFree()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for _, modeId in MatchModes.all() do
				if #getQueue(modeId).players > 0 then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)
end

return MatchmakingService
