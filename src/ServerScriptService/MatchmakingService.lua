local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTimers = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId] or MatchmakingConfig.MODES.training
end

local function isValidMode(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

local function getQueueStatus(modeId, queueSize)
	if MatchStateService.isBusy() then
		return "pending"
	end
	local config = getModeConfig(modeId)
	if queueSize >= config.minPlayers then
		return "ready"
	end
	return "waiting"
end

local function sendQueueUpdate(player, modeId, position)
	if not player.Parent then
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local queueSize = #queue

	Remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		queueSize = queueSize,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		position = position,
		status = getQueueStatus(modeId, queueSize),
		arenaBusy = MatchStateService.isBusy(),
	})
end

local function broadcastModeQueue(modeId)
	local queue = queues[modeId]
	for index, player in queue do
		sendQueueUpdate(player, modeId, index)
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function removePlayerFromQueue(player, silent)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil
	clearFillTimer(modeId)

	if not silent and player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	broadcastModeQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	removePlayerFromQueue(player, false)
end

local function takePlayersForMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, config.maxPlayers)
	local roster = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(roster, player)
		end
	end

	clearFillTimer(modeId)
	broadcastModeQueue(modeId)

	return roster
end

local function preparePlayersForMatch(players)
	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			status = "starting",
		})
		HubService.leaveHubForArena(player)
	end
end

local function startMatch(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	local roster = takePlayersForMatch(modeId)
	if #roster < config.minPlayers then
		for _, player in roster do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	preparePlayersForMatch(roster)
	MatchStateService.setBusy(true)
	Bindables.MatchReady:Fire(roster, modeId)
end

local function scheduleFillTimer(modeId)
	local config = getModeConfig(modeId)
	if config.fillTimeout <= 0 then
		return
	end
	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.delay(config.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		startMatch(modeId)
	end)
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		broadcastModeQueue(modeId)
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local queueSize = #queue

	if queueSize < config.minPlayers then
		return
	end

	if queueSize >= config.maxPlayers then
		startMatch(modeId)
		return
	end

	if config.fillTimeout > 0 then
		scheduleFillTimer(modeId)
	else
		startMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not isValidMode(modeId) then
		modeId = "training"
	end

	if MatchmakingService.isQueued(player) then
		if playerMode[player] == modeId then
			sendQueueUpdate(player, modeId, table.find(queues[modeId], player) or 1)
			return
		end
		removePlayerFromQueue(player, true)
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	broadcastModeQueue(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onMatchEnded()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removePlayerFromQueue(player, true)
end

return MatchmakingService
