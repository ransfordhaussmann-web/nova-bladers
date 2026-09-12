local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local ArenaFree = Bindables.ArenaFree

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillActive = {}
local fillTokens = {}

for _, modeId in MatchmakingConfig.MODE_ORDER do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function getQueuePlayers(modeId)
	local list = {}
	for player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function buildQueuePayload(modeId, player)
	local config = getModeConfig(modeId)
	local queued = getQueuePlayers(modeId)
	local status = "waiting"

	if GameMatchState.isArenaBusy() then
		status = "pending"
	elseif config.fillTimeout > 0 and #queued >= config.minPlayers and #queued < config.maxPlayers then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		queued = #queued,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		inQueue = playerMode[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId, nil)
	for player in queues[modeId] do
		if player.Parent then
			payload.inQueue = true
			QueueUpdate:FireClient(player, payload)
		end
	end
end

local function notifyPlayer(player, modeId)
	if not player.Parent then
		return
	end
	QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
end

local function clearFillTimer(modeId)
	fillActive[modeId] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function startFillTimer(modeId)
	local config = getModeConfig(modeId)
	if config.fillTimeout <= 0 or fillActive[modeId] then
		return
	end

	fillActive[modeId] = true
	local token = (fillTokens[modeId] or 0) + 1
	fillTokens[modeId] = token
	broadcastQueue(modeId)

	task.delay(config.fillTimeout, function()
		if fillTokens[modeId] ~= token or GameMatchState.isArenaBusy() then
			fillActive[modeId] = nil
			return
		end
		fillActive[modeId] = nil
		if canStartMode(modeId) then
			MatchmakingService.startMatch(modeId)
		end
	end)
end

local function removeFromAllQueues(player)
	local previousMode = playerMode[player]
	playerMode[player] = nil

	if not previousMode then
		return
	end

	queues[previousMode][player] = nil
	clearFillTimer(previousMode)
	broadcastQueue(previousMode)
end

local function canStartMode(modeId)
	local config = getModeConfig(modeId)
	local queued = getQueuePlayers(modeId)
	return #queued >= config.minPlayers
end

local function takePlayersForMatch(modeId)
	local config = getModeConfig(modeId)
	local queued = getQueuePlayers(modeId)
	local count = math.min(#queued, config.maxPlayers)
	local matchPlayers = {}

	for i = 1, count do
		local player = queued[i]
		matchPlayers[i] = player
		queues[modeId][player] = nil
		playerMode[player] = nil
	end

	clearFillTimer(modeId)
	broadcastQueue(modeId)
	return matchPlayers
end

function MatchmakingService.tryStartMatches()
	if GameMatchState.isArenaBusy() then
		return
	end

	for _, modeId in MatchmakingConfig.MODE_ORDER do
		local config = getModeConfig(modeId)
		local queued = getQueuePlayers(modeId)

		if #queued >= config.maxPlayers then
			MatchmakingService.startMatch(modeId)
			return
		end

		if #queued >= config.minPlayers then
			if config.fillTimeout > 0 and #queued < config.maxPlayers then
				startFillTimer(modeId)
				return
			end
			MatchmakingService.startMatch(modeId)
			return
		end
	end
end

function MatchmakingService.startMatch(modeId)
	if GameMatchState.isArenaBusy() or not canStartMode(modeId) then
		return
	end

	local players = takePlayersForMatch(modeId)
	if #players == 0 then
		return
	end

	for _, player in players do
		if HubService.getPhase(player) ~= "arena" then
			HubService.enterArena(player)
		end
	end

	MatchReady:Fire({
		mode = modeId,
		players = players,
	})
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end
	if GameMatchState.isArenaBusy() and playerMode[player] == modeId then
		notifyPlayer(player, modeId)
		return
	end

	removeFromAllQueues(player)
	queues[modeId][player] = true
	playerMode[player] = modeId

	notifyPlayer(player, modeId)
	broadcastQueue(modeId)
	MatchmakingService.tryStartMatches()
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromAllQueues(player)
	QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.onArenaFree()
	task.defer(MatchmakingService.tryStartMatches)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start()
	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
