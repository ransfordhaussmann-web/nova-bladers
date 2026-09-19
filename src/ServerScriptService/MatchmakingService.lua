local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillDeadlines = {}
local handlers = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getPlayerNames(playerList)
	local names = {}
	for _, player in playerList do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end
	return names
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue < MatchModes.get(modeId).minPlayers then
		fillDeadlines[modeId] = nil
	end
end

local function buildQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local valid = {}
	for _, queued in queue do
		if queued.Parent then
			table.insert(valid, queued)
		end
	end

	local status = "waiting"
	local fillSecondsLeft = nil

	if MatchStateService.isBusy() then
		status = "pending"
	elseif #valid >= mode.maxPlayers then
		status = "starting"
	elseif #valid >= mode.minPlayers then
		if mode.fillTimeout > 0 then
			status = "filling"
			local deadline = fillDeadlines[modeId]
			if deadline then
				fillSecondsLeft = math.max(0, math.ceil(deadline - os.clock()))
			end
		else
			status = "starting"
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = getPlayerNames(valid),
		count = #valid,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function broadcastQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueueUpdate(player))
	end
end

local function broadcastQueueUpdates()
	for player in playerQueue do
		broadcastQueueUpdate(player)
	end
end

local function startMatch(modeId, playerList)
	MatchStateService.setBusy(true)
	fillDeadlines[modeId] = nil

	for _, player in playerList do
		removeFromQueue(player)
		if handlers.onMatchStarting then
			handlers.onMatchStarting(player)
		end
	end

	broadcastQueueUpdates()
	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = playerList,
	})
end

local function tryStartQueue(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local ready = {}

	for _, player in queue do
		if player.Parent and handlers.isPlayerAvailable and handlers.isPlayerAvailable(player) then
			table.insert(ready, player)
		end
	end

	if #ready < mode.minPlayers then
		return
	end

	if #ready >= mode.maxPlayers then
		local matchPlayers = {}
		for i = 1, mode.maxPlayers do
			table.insert(matchPlayers, ready[i])
		end
		startMatch(modeId, matchPlayers)
		return
	end

	if mode.fillTimeout > 0 then
		local deadline = fillDeadlines[modeId]
		if not deadline then
			fillDeadlines[modeId] = os.clock() + mode.fillTimeout
			broadcastQueueUpdates()
			return
		end
		if os.clock() < deadline then
			return
		end
	end

	startMatch(modeId, ready)
end

local function processQueues()
	for _, mode in MatchModes.all() do
		tryStartQueue(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if handlers.isPlayerAvailable and not handlers.isPlayerAvailable(player) then
		return false
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if #queues[modeId] >= mode.minPlayers and mode.fillTimeout > 0 then
		if not fillDeadlines[modeId] then
			fillDeadlines[modeId] = os.clock() + mode.fillTimeout
		end
	end

	broadcastQueueUpdate(player)
	processQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	removeFromQueue(player)
	broadcastQueueUpdate(player)
	broadcastQueueUpdates()
end

function MatchmakingService.getRecommendedMode()
	if handlers.getRecommendedMode then
		return handlers.getRecommendedMode()
	end
	return "training"
end

function MatchmakingService.onMatchEnded()
	task.defer(processQueues)
end

function MatchmakingService.init(newHandlers)
	if started then
		return
	end
	started = true

	handlers = newHandlers or {}
	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			modeId = MatchmakingService.getRecommendedMode()
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
		MatchmakingService.leaveQueue(player)
	end)

	local lastTick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTick < MatchmakingConfig.QUEUE_TICK then
			return
		end
		lastTick = now
		processQueues()
		broadcastQueueUpdates()
	end)
end

return MatchmakingService
