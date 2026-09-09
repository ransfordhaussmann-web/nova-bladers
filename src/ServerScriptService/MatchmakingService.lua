local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function initQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillToken = 0,
			fillTimerActive = false,
		}
	end
	return queues[modeId]
end

local function removeFromList(list, player)
	for i, p in list do
		if p == player then
			table.remove(list, i)
			return true
		end
	end
	return false
end

local function getQueueStatus(modeId)
	local queue = queues[modeId]
	if not queue then
		return "waiting"
	end
	if MatchStateService.isArenaBusy() and #queue.players > 0 then
		return "pending"
	end
	return "waiting"
end

local function buildQueuePayload(modeId, player)
	local queue = initQueue(modeId)
	local position = 0
	for i, p in queue.players do
		if p == player then
			position = i
			break
		end
	end

	local mode = getMode(modeId)
	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		total = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = getQueueStatus(modeId),
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueue(modeId)
	local queue = initQueue(modeId)
	for _, player in queue.players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function shouldStartAfterFill(modeId, count)
	local mode = getMode(modeId)
	return count >= mode.minPlayers
end

local function clearFillTimer(queue)
	queue.fillToken += 1
end

local function startFillTimer(modeId)
	local queue = initQueue(modeId)
	if queue.fillTimerActive then
		return
	end
	queue.fillTimerActive = true
	clearFillTimer(queue)
	local token = queue.fillToken

	task.delay(MatchmakingConfig.FILL_TIMEOUT, function()
		queue.fillTimerActive = false
		if token ~= queue.fillToken then
			return
		end
		if shouldStartAfterFill(modeId, #queue.players) then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

local function shouldStartImmediately(modeId, count)
	local mode = getMode(modeId)
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "training" and count >= 1 then
		return true
	end
	if modeId == "pvp" and count >= 2 then
		return true
	end
	return false
end

function MatchmakingService.tryStartMatch(modeId)
	local queue = initQueue(modeId)
	local mode = getMode(modeId)
	if not mode or #queue.players < mode.minPlayers then
		return false
	end
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end

	local playerList = {}
	for i = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(playerList, queue.players[i])
	end

	for _, player in playerList do
		removeFromList(queue.players, player)
		playerQueue[player] = nil
	end
	clearFillTimer(queue)
	broadcastQueue(modeId)

	for _, player in playerList do
		HubService.enterArena(player)
	end

	Bindables.MatchReady:Fire(playerList, modeId)
	return true
end

local function evaluateQueue(modeId)
	local queue = initQueue(modeId)
	local count = #queue.players
	local mode = getMode(modeId)
	if count == 0 then
		return
	end

	if shouldStartImmediately(modeId, count) then
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if modeId == "ffa" and count >= mode.minPlayers and not queue.fillTimerActive then
		startFillTimer(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = initQueue(modeId)
	removeFromList(queue.players, player)
	playerQueue[player] = nil

	if #queue.players < getMode(modeId).minPlayers then
		queue.fillTimerActive = false
		clearFillTimer(queue)
	end

	broadcastQueue(modeId)
	Remotes.QueueUpdate:FireClient(player, { left = true })
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	MatchmakingService.leaveQueue(player)

	local queue = initQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	broadcastQueue(modeId)
	evaluateQueue(modeId)
end

function MatchmakingService.getSuggestedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init()
	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		for modeId in MatchmakingConfig.MODES do
			evaluateQueue(modeId)
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

return MatchmakingService
