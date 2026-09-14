--[[
	MatchmakingService — server-side queue for Training / PvP / FFA matches.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local ArenaFree = Bindables.ArenaFree

local MatchmakingService = {}

local handlers = {}
local queues = {}
local playerQueue = {}
local pendingMatch = nil
local tickRunning = false

for _, modeId in { "training", "pvp", "ffa" } do
	queues[modeId] = { players = {}, fillDeadline = nil }
end

local function getQueuePlayers(modeId)
	local queue = queues[modeId]
	if not queue then
		return {}
	end
	local alive = {}
	for _, player in queue.players do
		if player.Parent then
			table.insert(alive, player)
		end
	end
	queue.players = alive
	return alive
end

local function buildPayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local waiting = #getQueuePlayers(modeId)
	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersWaiting = waiting,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
	}

	local queue = queues[modeId]
	if mode.fillTimeout and queue.fillDeadline and waiting >= mode.minPlayers and waiting < mode.maxPlayers then
		payload.secondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return payload
end

local function sendUpdate(player, modeId, status)
	if player.Parent then
		QueueUpdate:FireClient(player, buildPayload(player, modeId, status))
	end
end

local function broadcastModeUpdate(modeId, status)
	for _, player in getQueuePlayers(modeId) do
		sendUpdate(player, modeId, status)
	end
end

local function clearPlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	if not queue then
		return
	end

	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players < MatchModes.get(modeId).minPlayers then
		queue.fillDeadline = nil
	end

	if player.Parent then
		QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastModeUpdate(modeId, "waiting")
end

local function removeFromPending(player)
	if not pendingMatch then
		return false
	end

	for i, p in pendingMatch.players do
		if p == player then
			table.remove(pendingMatch.players, i)
			break
		end
	end

	local mode = MatchModes.get(pendingMatch.modeId)
	if #pendingMatch.players < mode.minPlayers then
		pendingMatch = nil
		return true
	end

	for _, p in pendingMatch.players do
		sendUpdate(p, pendingMatch.modeId, "pending")
	end
	return true
end

local function launchMatch(modeId, players)
	for _, player in players do
		playerQueue[player] = nil
		if player.Parent then
			QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
			if handlers.onPlayerEnterArena then
				handlers.onPlayerEnterArena(player)
			end
		end
	end

	GameMatchState.setBusy(true)
	MatchReady:Fire(modeId, players)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local players = getQueuePlayers(modeId)
	if #players < mode.minPlayers then
		return
	end

	local queue = queues[modeId]
	if mode.fillTimeout and #players < mode.maxPlayers then
		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + mode.fillTimeout
		end
		if os.clock() < queue.fillDeadline then
			broadcastModeUpdate(modeId, "waiting")
			return
		end
	end

	queue.players = {}
	queue.fillDeadline = nil

	if GameMatchState.isBusy() then
		pendingMatch = { modeId = modeId, players = players }
		for _, player in players do
			playerQueue[player] = modeId
			sendUpdate(player, modeId, "pending")
		end
		return
	end

	launchMatch(modeId, players)
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	if pendingMatch then
		for _, p in pendingMatch.players do
			if p == player then
				return
			end
		end
	end

	if playerQueue[player] == modeId then
		return
	end

	clearPlayerFromQueue(player)
	playerQueue[player] = modeId
	table.insert(queues[modeId].players, player)
	broadcastModeUpdate(modeId, "waiting")
	tryStartMatch(modeId)
end

local function leaveQueue(player)
	if removeFromPending(player) then
		if player.Parent then
			QueueUpdate:FireClient(player, { inQueue = false })
		end
		return
	end
	clearPlayerFromQueue(player)
end

local function onArenaFree()
	if not pendingMatch or GameMatchState.isBusy() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	local mode = MatchModes.get(match.modeId)
	local alive = {}
	for _, player in match.players do
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(alive, player)
		end
	end

	if #alive < mode.minPlayers then
		return
	end

	launchMatch(match.modeId, alive)
end

local function queueTick()
	for modeId, queue in queues do
		if queue.fillDeadline and os.clock() >= queue.fillDeadline then
			tryStartMatch(modeId)
		else
			local mode = MatchModes.get(modeId)
			if queue.fillDeadline and #getQueuePlayers(modeId) >= mode.minPlayers then
				broadcastModeUpdate(modeId, "waiting")
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.getRecommendedMode()
	if handlers.getRecommendedMode then
		return handlers.getRecommendedMode()
	end
	return "training"
end

function MatchmakingService.start(newHandlers)
	handlers = newHandlers or {}

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedMode()
		end
		joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	ArenaFree.Event:Connect(onArenaFree)

	if not tickRunning then
		tickRunning = true
		task.spawn(function()
			while true do
				task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
				queueTick()
			end
		end)
	end
end

return MatchmakingService
