local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local Bindables
local queues = {}
local playerQueue = {}
local initialized = false

local function initQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillToken = 0,
			fillEndsAt = nil,
		}
	end
end

local function getFillTimeLeft(queue, mode)
	if not mode.fillTimeout or not queue.fillEndsAt then
		return nil
	end
	return math.max(0, math.ceil(queue.fillEndsAt - os.clock()))
end

local function buildQueuePayload(modeId, player)
	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	local count = #queue.players
	local status = "waiting"
	if MatchStateService.isArenaBusy() and count >= mode.minPlayers then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = player ~= nil and table.find(queue.players, player) ~= nil,
		fillTimeLeft = getFillTimeLeft(queue, mode),
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, queuedPlayer in queue.players do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	local index = table.find(queue.players, player)
	if index then
		table.remove(queue.players, index)
	end
	playerQueue[player] = nil

	if #queue.players < MatchModes.get(modeId).minPlayers then
		queue.fillToken += 1
		queue.fillEndsAt = nil
	end

	broadcastQueueUpdate(modeId)
end

local function takeMatchPlayers(modeId)
	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	local matchPlayers = {}

	for i = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(matchPlayers, queue.players[i])
	end

	for _, matchPlayer in matchPlayers do
		removePlayerFromQueue(matchPlayer)
	end

	queue.fillToken += 1
	queue.fillEndsAt = nil

	return matchPlayers
end

local function tryStartMatch(modeId)
	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	if #queue.players < mode.minPlayers then
		return false
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return false
	end

	local matchPlayers = takeMatchPlayers(modeId)
	if #matchPlayers < mode.minPlayers then
		return false
	end

	MatchStateService.setArenaBusy(true)
	Bindables.MatchReady:Fire(modeId, matchPlayers)
	return true
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	local queue = queues[modeId]
	queue.fillToken += 1
	local token = queue.fillToken
	queue.fillEndsAt = os.clock() + mode.fillTimeout

	task.spawn(function()
		while token == queue.fillToken and queue.fillEndsAt do
			if #queue.players >= mode.maxPlayers then
				tryStartMatch(modeId)
				return
			end
			if #queue.players < mode.minPlayers then
				return
			end

			broadcastQueueUpdate(modeId)
			local remaining = queue.fillEndsAt - os.clock()
			if remaining <= 0 then
				tryStartMatch(modeId)
				return
			end
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
		end
	end)
end

local function onQueueReady(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	if count >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if modeId == "ffa" and count >= mode.minPlayers then
		if not queue.fillEndsAt then
			startFillTimer(modeId)
		end
		return
	end

	if count >= mode.minPlayers then
		tryStartMatch(modeId)
	end
end

function MatchmakingService.getQuickMatchMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] == modeId then
		return true
	end

	removePlayerFromQueue(player)
	initQueue(modeId)

	local queue = queues[modeId]
	if #queue.players >= mode.maxPlayers then
		return false
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)
	onQueueReady(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removePlayerFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()

	for _, modeId in MatchModes.getAll() do
		initQueue(modeId)
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
			modeId = MatchmakingService.getQuickMatchMode()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		for _, modeId in MatchModes.getAll() do
			local queue = queues[modeId]
			local mode = MatchModes.get(modeId)
			if #queue.players >= mode.minPlayers then
				if modeId == "ffa" and not queue.fillEndsAt and #queue.players < mode.maxPlayers then
					startFillTimer(modeId)
				else
					tryStartMatch(modeId)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
