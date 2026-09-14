local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local MatchReady
local queues = {}
local playerQueue = {}
local fillTimers = {}
local hubCallbacks = {}

local function initQueues()
	for _, modeId in { "training", "pvp", "ffa" } do
		queues[modeId] = {
			players = {},
			status = "idle",
		}
	end
end

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function getQueuePlayers(modeId)
	local queue = queues[modeId]
	if not queue then
		return {}
	end
	local list = {}
	for _, player in queue.players do
		if isValidPlayer(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local players = getQueuePlayers(modeId)
	local queue = queues[modeId]
	local status = queue and queue.status or "idle"

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = #players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = GameMatchState.isArenaBusy(),
		inQueue = player ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local players = getQueuePlayers(modeId)
	for _, player in players do
		if isValidPlayer(player) then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function cancelFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function setQueueStatus(modeId, status)
	local queue = queues[modeId]
	if queue then
		queue.status = status
	end
end

local function removePlayerFromAllQueues(player)
	local previousMode = playerQueue[player]
	playerQueue[player] = nil

	for modeId, queue in queues do
		local idx = table.find(queue.players, player)
		if idx then
			table.remove(queue.players, idx)
		end
		if #getQueuePlayers(modeId) == 0 then
			setQueueStatus(modeId, "idle")
			cancelFillTimer(modeId)
		end
	end

	if previousMode then
		broadcastQueueUpdate(previousMode)
	end
end

local function resolveMatchFromQueue(modeId)
	local mode = MatchModes.get(modeId)
	local players = getQueuePlayers(modeId)
	local count = #players

	if count == 0 then
		return nil
	end

	if modeId == "ffa" and count < mode.minPlayers then
		if count >= 2 then
			return players, "pvp", 2
		end
		return players, "training", 1
	end

	local take = math.min(count, mode.maxPlayers)
	return players, modeId, take
end

local function pullPlayersFromQueue(modeId, take)
	local queue = queues[modeId]
	local selected = {}
	for _ = 1, take do
		local player = table.remove(queue.players, 1)
		if isValidPlayer(player) then
			table.insert(selected, player)
			playerQueue[player] = nil
		end
	end

	if #getQueuePlayers(modeId) == 0 then
		setQueueStatus(modeId, "idle")
		cancelFillTimer(modeId)
	end

	return selected
end

local function startMatch(modeId)
	local players, resolvedMode, take = resolveMatchFromQueue(modeId)
	if not players or take <= 0 then
		return false
	end

	if GameMatchState.isArenaBusy() then
		setQueueStatus(modeId, "pending")
		broadcastQueueUpdate(modeId)
		return false
	end

	local matchPlayers = pullPlayersFromQueue(modeId, take)
	if #matchPlayers == 0 then
		setQueueStatus(modeId, "idle")
		return false
	end

	setQueueStatus(modeId, "idle")
	GameMatchState.setArenaBusy(true)

	for _, player in matchPlayers do
		if hubCallbacks.leaveHubForArena then
			hubCallbacks.leaveHubForArena(player)
		end
	end

	MatchReady:Fire(matchPlayers, resolvedMode)
	broadcastQueueUpdate(modeId)
	return true
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local players = getQueuePlayers(modeId)
	local count = #players

	if count == 0 then
		setQueueStatus(modeId, "idle")
		return
	end

	if count >= mode.minPlayers then
		if GameMatchState.isArenaBusy() then
			setQueueStatus(modeId, "pending")
			broadcastQueueUpdate(modeId)
			return
		end
		startMatch(modeId)
		return
	end

	if modeId == "ffa" and mode.fillTimeout and count >= 1 and not fillTimers[modeId] then
		setQueueStatus(modeId, "waiting")
		fillTimers[modeId] = task.delay(mode.fillTimeout, function()
			fillTimers[modeId] = nil
			if #getQueuePlayers(modeId) > 0 then
				startMatch(modeId)
			else
				setQueueStatus(modeId, "idle")
			end
		end)
	end

	broadcastQueueUpdate(modeId)
end

local function joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return
	end
	if not queues[modeId] then
		modeId = MatchModes.resolveAuto(1)
	end
	if GameMatchState.isArenaBusy() and playerQueue[player] == modeId then
		setQueueStatus(modeId, "pending")
	end

	removePlayerFromAllQueues(player)

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	if GameMatchState.isArenaBusy() then
		setQueueStatus(modeId, "pending")
	else
		setQueueStatus(modeId, "waiting")
	end

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	tryStartMatch(modeId)
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removePlayerFromAllQueues(player)
	Remotes.QueueUpdate:FireClient(player, {
		modeId = nil,
		inQueue = false,
		status = "idle",
		arenaBusy = GameMatchState.isArenaBusy(),
	})
end

local function onArenaFree()
	for modeId, queue in queues do
		if queue.status == "pending" or #getQueuePlayers(modeId) > 0 then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.joinAutoQueue(player)
	local count = #Players:GetPlayers()
	joinQueue(player, MatchModes.resolveAuto(count))
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.start(callbacks)
	hubCallbacks = callbacks or {}
	initQueues()

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			MatchmakingService.joinAutoQueue(player)
			return
		end
		if modeId == "auto" then
			MatchmakingService.joinAutoQueue(player)
			return
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromAllQueues(player)
	end)

	GameMatchState.onArenaFree(onArenaFree)
end

return MatchmakingService
