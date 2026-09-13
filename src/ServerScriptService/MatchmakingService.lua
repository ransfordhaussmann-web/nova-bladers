local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTokens = {}
local remotes
local bindables
local started = false

local START_PRIORITY = { "pvp", "ffa", "training" }

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getQueueCount(modeId)
	return #ensureQueue(modeId)
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local info = playerQueue[player]
	return {
		modeId = modeId,
		label = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = table.find(queue, player),
		pending = info and info.pending or false,
		arenaBusy = GameMatchState.isArenaBusy(),
		fillTimeout = mode.fillTimeout,
	}
end

local function sendQueueUpdate(player)
	local info = playerQueue[player]
	if not info then
		return
	end
	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, info.modeId))
end

local function broadcastQueueUpdate(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function clearPlayerQueue(player)
	local info = playerQueue[player]
	if not info then
		return
	end

	local modeId = info.modeId
	local queue = ensureQueue(modeId)
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
	end
	playerQueue[player] = nil

	local mode = MatchModes.get(modeId)
	if mode and getQueueCount(modeId) < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
end

local function markQueuePending(modeId)
	for _, player in ensureQueue(modeId) do
		local info = playerQueue[player]
		if info then
			info.pending = true
		end
	end
	broadcastQueueUpdate(modeId)
end

local function takeMatchPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local matchPlayers = {}

	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		playerQueue[player] = nil
	end

	queues[modeId] = {}
	cancelFillTimer(modeId)

	return matchPlayers
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	if GameMatchState.isArenaBusy() then
		markQueuePending(modeId)
		return false
	end

	local matchPlayers = takeMatchPlayers(modeId)
	if #matchPlayers < mode.minPlayers then
		for _, player in matchPlayers do
			MatchmakingService.joinQueue(player, modeId)
		end
		return false
	end

	GameMatchState.setArenaBusy(true)
	for _, player in matchPlayers do
		HubService.prepareForArena(player)
	end
	bindables.MatchReady:Fire(matchPlayers, modeId)
	return true
end

local function tryStartAnyQueue()
	for _, modeId in START_PRIORITY do
		if tryStartMatch(modeId) then
			return true
		end
	end
	return false
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		if getQueueCount(modeId) >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = getQueueCount(modeId)
	if count >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if count >= mode.minPlayers and mode.fillTimeout <= 0 then
		tryStartMatch(modeId)
		return
	end

	if count >= mode.minPlayers and mode.fillTimeout > 0 and count == mode.minPlayers then
		scheduleFillTimer(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchModes.getRecommended(#Players:GetPlayers()).id
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	clearPlayerQueue(player)

	local queue = ensureQueue(modeId)
	if table.find(queue, player) then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = {
		modeId = modeId,
		pending = GameMatchState.isArenaBusy(),
	}

	sendQueueUpdate(player)
	evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	clearPlayerQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	local info = playerQueue[player]
	return info and info.modeId
end

function MatchmakingService.onArenaFree()
	task.defer(tryStartAnyQueue)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	remotes, bindables = RemotesSetup.ensure()

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearPlayerQueue(player)
	end)

	bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
