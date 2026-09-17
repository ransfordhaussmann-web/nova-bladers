local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}

local function initQueues()
	for _, modeId in MatchModes.all() do
		queues[modeId] = {
			players = {},
			pending = false,
			fillScheduled = false,
		}
		fillTokens[modeId] = 0
	end
end

local function resolveModeId(modeId)
	if modeId == "auto" or modeId == nil then
		return MatchModes.recommendForServerCount(#Players:GetPlayers())
	end
	if MatchModes.get(modeId) then
		return modeId
	end
	return "training"
end

local function getQueuePayload(modeId, forPlayer)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local names = {}
	for _, player in queue.players do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end

	local position = nil
	for i, player in queue.players do
		if player == forPlayer then
			position = i
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		pending = queue.pending or MatchStateService.isBusy(),
		inQueue = forPlayer ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue.players do
		if player.Parent and HubService.getPhase(player) == "hub" then
			Remotes.QueueUpdate:FireClient(player, getQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for _, modeId in MatchModes.all() do
		broadcastQueueUpdate(modeId)
	end
end

local function removeFromQueue(player)
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

	if #queue.players == 0 then
		queue.pending = false
		queue.fillScheduled = false
		fillTokens[modeId] += 1
	end

	broadcastQueueUpdate(modeId)
end

local function takePlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local taken = {}
	local limit = math.min(#queue.players, mode.maxPlayers)

	for i = 1, limit do
		local player = queue.players[i]
		if player and player.Parent then
			table.insert(taken, player)
		end
	end

	for _, player in taken do
		removeFromQueue(player)
	end

	queue.pending = false
	queue.fillScheduled = false
	fillTokens[modeId] += 1

	return taken
end

local function launchMatch(modeId)
	local players = takePlayers(modeId)
	if #players == 0 then
		return
	end

	MatchStateService.setBusy(true)

	for _, player in players do
		HubService.enterArena(player)
	end

	MatchReady:Fire(players)
end

local function tryStartMatch(modeId, forceStart)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]

	if #queue.players < mode.minPlayers then
		queue.pending = false
		broadcastQueueUpdate(modeId)
		return
	end

	if MatchStateService.isBusy() then
		queue.pending = true
		broadcastQueueUpdate(modeId)
		return
	end

	if modeId == "ffa" then
		if forceStart or #queue.players >= mode.maxPlayers then
			launchMatch(modeId)
			return
		end

		if not queue.fillScheduled then
			queue.fillScheduled = true
			fillTokens[modeId] += 1
			local token = fillTokens[modeId]
			local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT

			task.delay(timeout, function()
				queue.fillScheduled = false
				if token ~= fillTokens[modeId] then
					return
				end
				if #queues[modeId].players < mode.minPlayers then
					return
				end
				tryStartMatch(modeId, true)
			end)
		end
		return
	end

	launchMatch(modeId)
end

local function joinQueue(player, requestedModeId)
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	local modeId = resolveModeId(requestedModeId)
	removeFromQueue(player)

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end
	removeFromQueue(player)
end

local function processPendingQueues()
	for _, modeId in MatchModes.all() do
		local queue = queues[modeId]
		if #queue.players > 0 then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.init(remotes, bindables)
	Remotes = remotes
	MatchReady = bindables.MatchReady
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		processPendingQueues()
	end)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

return MatchmakingService
