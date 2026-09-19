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

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillEndsAt = {}
local callbacks = {}

for modeId in MatchModes do
	queues[modeId] = { players = {}, fillToken = 0 }
end

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

local function getQueueSize(modeId)
	return #queues[modeId].players
end

local function buildUpdatePayload(player, modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local pending = not MatchStateService.isAvailable()
	local fillEnd = fillEndsAt[modeId]
	local fillSecondsLeft = nil
	if fillEnd then
		fillSecondsLeft = math.max(0, math.ceil(fillEnd - os.clock()))
	end

	local status = "waiting"
	if pending then
		status = "pending"
	elseif fillSecondsLeft and fillSecondsLeft > 0 then
		status = "filling"
	elseif getQueueSize(modeId) >= mode.maxPlayers then
		status = "starting"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = getQueueSize(modeId),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillSecondsLeft = fillSecondsLeft,
		pending = pending,
		status = status,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue.players do
		if player.Parent then
			QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId))
		end
	end
end

local function clearFillTimer(modeId)
	queues[modeId].fillToken += 1
	fillEndsAt[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	local queue = queues[modeId]
	queue.fillToken += 1
	local token = queue.fillToken
	fillEndsAt[modeId] = os.clock() + mode.fillTimeout

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		fillEndsAt[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	local count = #queue.players

	if count < mode.minPlayers then
		return
	end
	if not MatchStateService.isAvailable() then
		broadcastQueueUpdate(modeId)
		return
	end

	if count >= mode.maxPlayers then
		MatchmakingService.startMatchFromQueue(modeId)
		return
	end

	if mode.fillTimeout > 0 then
		if not fillEndsAt[modeId] then
			startFillTimer(modeId)
			broadcastQueueUpdate(modeId)
		end
		return
	end

	if count >= mode.minPlayers then
		MatchmakingService.startMatchFromQueue(modeId)
	end
end

function MatchmakingService.startMatchFromQueue(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]

	if #queue.players < mode.minPlayers then
		return
	end
	if not MatchStateService.isAvailable() then
		broadcastQueueUpdate(modeId)
		return
	end

	clearFillTimer(modeId)

	local take = math.min(#queue.players, mode.maxPlayers)
	local matched = {}
	for i = 1, take do
		table.insert(matched, queue.players[i])
	end

	for i = 1, take do
		table.remove(queue.players, 1)
	end

	for _, player in matched do
		playerQueue[player] = nil
		QueueUpdate:FireClient(player, { inQueue = false })
	end

	broadcastQueueUpdate(modeId)

	MatchReady:Fire({ players = matched, mode = modeId })

	if callbacks.onMatchReady then
		callbacks.onMatchReady(matched, modeId)
	end
end

function MatchmakingService.tryStartAllQueues()
	for modeId in MatchModes do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return
	end

	if isPlayerQueued(player) then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId

	QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId))

	if callbacks.onPlayerQueued then
		callbacks.onPlayerQueued(player, modeId)
	end

	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerQueue[player] = nil
	QueueUpdate:FireClient(player, { inQueue = false })

	local mode = getMode(modeId)
	if mode and mode.fillTimeout > 0 and #queue.players < mode.minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)

	if callbacks.onPlayerLeftQueue then
		callbacks.onPlayerLeftQueue(player, modeId)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(options)
	callbacks = options or {}
	local resolveMode = callbacks.resolveMode or function()
		return "training"
	end

	MatchStateService.whenAvailable(function()
		MatchmakingService.tryStartAllQueues()
	end)

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not getMode(modeId) then
			modeId = resolveMode(player)
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId in MatchModes do
				if #queues[modeId].players > 0 then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)
end

return MatchmakingService
