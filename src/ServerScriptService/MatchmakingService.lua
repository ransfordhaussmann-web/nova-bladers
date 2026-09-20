local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local ffaFillToken = 0
local hubCallbacks = {}

local function initQueues()
	for modeId in MatchModes.MODES do
		queues[modeId] = {}
	end
end

local function getQueueCount(modeId)
	return #(queues[modeId] or {})
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
end

local function buildUpdateForPlayer(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.getMode(modeId)
	local queue = queues[modeId]
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local total = #queue
	local pendingArena = MatchStateService.isArenaBusy()
	local status = "waiting"

	if pendingArena then
		status = "pending"
	elseif modeId == "training" and total >= mode.minPlayers then
		status = "starting"
	elseif modeId == "pvp" and total >= mode.minPlayers then
		status = "starting"
	elseif modeId == "ffa" and total >= mode.maxPlayers then
		status = "starting"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		total = total,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pendingArena = pendingArena,
		status = status,
	}
end

local function broadcastQueueUpdates()
	for player in playerQueue do
		if player.Parent then
			QueueUpdate:FireClient(player, buildUpdateForPlayer(player))
		end
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
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

	playerQueue[player] = nil

	if modeId == "ffa" and getQueueCount("ffa") < MatchModes.MODES.ffa.minPlayers then
		cancelFfaFillTimer()
	end
end

local function extractPlayersForMatch(modeId)
	local mode = MatchModes.getMode(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local players = {}

	for index = 1, count do
		table.insert(players, queue[index])
	end

	for _, matchPlayer in players do
		removePlayerFromQueue(matchPlayer)
	end

	return players
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	if hubCallbacks.onMatchReady then
		hubCallbacks.onMatchReady(modeId, players)
	end
	MatchReady:Fire(modeId, players)
	broadcastQueueUpdates()
end

local function canStartMode(modeId)
	local mode = MatchModes.getMode(modeId)
	local count = getQueueCount(modeId)
	return count >= mode.minPlayers
end

local function tryStartMode(modeId)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local mode = MatchModes.getMode(modeId)
	local count = getQueueCount(modeId)

	if modeId == "training" and count >= 1 then
		launchMatch(modeId, extractPlayersForMatch(modeId))
		return true
	end

	if modeId == "pvp" and count >= 2 then
		launchMatch(modeId, extractPlayersForMatch(modeId))
		return true
	end

	if modeId == "ffa" and count >= mode.maxPlayers then
		cancelFfaFillTimer()
		launchMatch(modeId, extractPlayersForMatch(modeId))
		return true
	end

	return false
end

local function tryStartAnyQueue()
	for _, modeId in MatchmakingConfig.QUEUE_PRIORITY do
		if tryStartMode(modeId) then
			return
		end
	end
end

local function startFfaFillTimer()
	local mode = MatchModes.MODES.ffa
	if getQueueCount("ffa") < mode.minPlayers then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end

		if MatchStateService.isArenaBusy() then
			broadcastQueueUpdates()
			return
		end

		if getQueueCount("ffa") >= mode.minPlayers then
			launchMatch("ffa", extractPlayersForMatch("ffa"))
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	if typeof(modeId) ~= "string" or not MatchModes.getMode(modeId) then
		modeId = MatchModes.getRecommendedModeId()
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdates()

	if modeId == "ffa" then
		if getQueueCount("ffa") >= MatchModes.MODES.ffa.maxPlayers then
			tryStartMode("ffa")
		elseif getQueueCount("ffa") >= MatchModes.MODES.ffa.minPlayers then
			startFfaFillTimer()
			tryStartAnyQueue()
		end
		return
	end

	tryStartAnyQueue()
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	removePlayerFromQueue(player)
	QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdates()
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	tryStartAnyQueue()

	if getQueueCount("ffa") >= MatchModes.MODES.ffa.minPlayers and not MatchStateService.isArenaBusy() then
		startFfaFillTimer()
	end

	broadcastQueueUpdates()
end

function MatchmakingService.init(callbacks)
	initQueues()
	hubCallbacks = callbacks or {}

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onArenaFreed()
	end)
end

return MatchmakingService
