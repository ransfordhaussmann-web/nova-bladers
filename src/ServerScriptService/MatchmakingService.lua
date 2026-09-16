local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTokens = {}
local fillScheduled = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function buildUpdatePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId] or {}
	local pending = MatchStateService.isArenaBusy()
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		fillTimeout = mode and mode.fillTimeout or 0,
		pending = pending,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, player in queue do
		if player.Parent then
			QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, p in queue do
			if p == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillScheduled[modeId] = nil
	broadcastQueueUpdate(modeId)
end

local function popQueuePlayers(modeId, count)
	local queue = queues[modeId]
	if not queue then
		return {}
	end

	local picked = {}
	for i = 1, math.min(count, #queue) do
		table.insert(picked, queue[1])
		playerQueue[queue[1]] = nil
		table.remove(queue, 1)
	end

	broadcastQueueUpdate(modeId)
	return picked
end

local function leaveHubForMatch(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	HubService.leaveHubForArena(player)
end

local function fireMatchReady(modeId, playerList)
	for _, player in playerList do
		leaveHubForMatch(player)
	end
	MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local queue = queues[modeId]
	if not queue or #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout > 0 then
		return
	end

	local players = popQueuePlayers(modeId, mode.maxPlayers)
	if #players >= mode.minPlayers then
		fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
		fireMatchReady(modeId, players)
	end
end

local function scheduleFillStart(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	if fillScheduled[modeId] then
		return
	end

	local queue = queues[modeId]
	if not queue or #queue < mode.minPlayers then
		return
	end

	fillScheduled[modeId] = true
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		fillScheduled[modeId] = nil
		if token ~= fillTokens[modeId] then
			return
		end

		local current = queues[modeId]
		if not current or #current < mode.minPlayers then
			return
		end

		if MatchStateService.isArenaBusy() then
			scheduleFillStart(modeId)
			return
		end

		local players = popQueuePlayers(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			fireMatchReady(modeId, players)
		end
	end)
end

local function getSuggestedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getSuggestedModeId()
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
			return true
		end
		removeFromQueue(player)
	end

	local queue = queues[modeId]
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
	broadcastQueueUpdate(modeId)

	if #queue >= mode.minPlayers then
		if mode.fillTimeout > 0 then
			scheduleFillStart(modeId)
		else
			tryStartMatch(modeId)
		end
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	for modeId in queues do
		local mode = MatchModes.get(modeId)
		local queue = queues[modeId]
		if mode and queue and #queue >= mode.minPlayers then
			if mode.fillTimeout > 0 then
				scheduleFillStart(modeId)
			else
				tryStartMatch(modeId)
			end
		else
			broadcastQueueUpdate(modeId)
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true
	initQueues()

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
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
			task.wait(MatchmakingConfig.ARENA_BUSY_POLL)
			if MatchStateService.isArenaBusy() then
				broadcastAllQueues()
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
