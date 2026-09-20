local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local bindables
local callbacks = {}

local queues = {}
local playerQueue = {}
local fillTasks = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillStartedAt = nil,
		}
	end
	return queues[modeId]
end

local function queueCount(modeId)
	return #getQueue(modeId).players
end

local function isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

local function removeFromQueue(player)
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

	if queueCount(modeId) < MatchModes.get(modeId).minPlayers then
		queue.fillStartedAt = nil
		if fillTasks[modeId] then
			task.cancel(fillTasks[modeId])
			fillTasks[modeId] = nil
		end
	end
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players
	local status = "waiting"

	if count >= mode.minPlayers and MatchStateService.isBusy() then
		status = "pending"
	elseif count >= mode.maxPlayers then
		status = "starting"
	end

	local fillSecondsLeft
	if mode.fillTimeout and queue.fillStartedAt and count >= mode.minPlayers and count < mode.maxPlayers then
		fillSecondsLeft = math.max(0, math.ceil(mode.fillTimeout - (os.clock() - queue.fillStartedAt)))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function clearQueueUpdate(player)
	if player.Parent then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end

	if modeId == "training" then
		return count >= 1
	end

	if modeId == "pvp" then
		return count >= 2
	end

	if count >= mode.maxPlayers then
		return true
	end

	if mode.fillTimeout and queue.fillStartedAt then
		return (os.clock() - queue.fillStartedAt) >= mode.fillTimeout
	end

	return false
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout or fillTasks[modeId] then
		return
	end

	local queue = getQueue(modeId)
	if queue.fillStartedAt then
		return
	end

	queue.fillStartedAt = os.clock()
	fillTasks[modeId] = task.delay(mode.fillTimeout, function()
		fillTasks[modeId] = nil
		MatchmakingService.tryStartMatches()
	end)
end

function MatchmakingService.tryStartMatches()
	if MatchStateService.isBusy() then
		for _, mode in MatchModes.all() do
			if canStartMode(mode.id) then
				broadcastQueue(mode.id)
			end
		end
		return
	end

	for _, mode in MatchModes.all() do
		if canStartMode(mode.id) then
			MatchmakingService.startMatch(mode.id)
			return
		end
	end
end

function MatchmakingService.startMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or MatchStateService.isBusy() or not canStartMode(modeId) then
		return
	end

	local queue = getQueue(modeId)
	local matchPlayers = {}
	for index = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(matchPlayers, queue.players[index])
	end

	if #matchPlayers < mode.minPlayers then
		return
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
		clearQueueUpdate(player)
	end

	queue.fillStartedAt = nil
	if fillTasks[modeId] then
		task.cancel(fillTasks[modeId])
		fillTasks[modeId] = nil
	end

	if callbacks.onMatchStarting then
		callbacks.onMatchStarting(matchPlayers, modeId)
	end

	bindables.MatchReady:Fire({
		modeId = modeId,
		players = matchPlayers,
	})
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode or not player.Parent then
		return
	end

	if callbacks.getPhase and callbacks.getPhase(player) ~= "hub" then
		return
	end

	if isPlayerQueued(player) then
		removeFromQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue.players >= mode.maxPlayers then
		return
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId

	if modeId == "ffa" and #queue.players >= mode.minPlayers then
		startFillTimer(modeId)
	end

	broadcastQueue(modeId)
	MatchmakingService.tryStartMatches()
end

function MatchmakingService.leaveQueue(player)
	if not isPlayerQueued(player) then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	clearQueueUpdate(player)
	if modeId then
		broadcastQueue(modeId)
	end
end

function MatchmakingService.init(options)
	remotes = options.remotes
	bindables = options.bindables
	callbacks = options.callbacks or {}

	for _, mode in MatchModes.all() do
		getQueue(mode.id)
	end

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.MatchEnded.Event:Connect(function()
		MatchStateService.setBusy(false)
		task.defer(MatchmakingService.tryStartMatches)
	end)

	MatchStateService.onArenaFree(function()
		MatchmakingService.tryStartMatches()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
