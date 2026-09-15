local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerMode = {}
local fillTimers = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {
			players = {},
			fillDeadline = nil,
		}
	end
end

local function getQueueSize(modeId)
	local queue = queues[modeId]
	return queue and #queue.players or 0
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local size = getQueueSize(modeId)
	local pending = MatchStateService.isArenaBusy()
	return {
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = size,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		inQueue = playerMode[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for _, queuedPlayer in queue.players do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer, modeId))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
	local queue = queues[modeId]
	if queue then
		queue.fillDeadline = nil
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, i)
				break
			end
		end

		if #queue.players < MatchModes.get(modeId).minPlayers then
			clearFillTimer(modeId)
		end
	end

	playerMode[player] = nil

	if not silent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		broadcastQueue(modeId)
	end
end

local function takePlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local taken = {}
	local count = math.min(#queue.players, mode.maxPlayers)

	for i = 1, count do
		table.insert(taken, queue.players[i])
	end

	for i = count, 1, -1 do
		table.remove(queue.players, i)
	end

	clearFillTimer(modeId)

	for _, p in taken do
		playerMode[p] = nil
		Remotes.QueueUpdate:FireClient(p, { inQueue = false })
	end

	return taken
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	for _, p in players do
		HubService.prepareForArena(p)
	end

	Bindables.MatchReady:Fire({
		players = players,
		mode = modeId,
	})
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local size = #queue.players

	if size < mode.minPlayers then
		return
	end

	if size >= mode.maxPlayers then
		launchMatch(modeId, takePlayers(modeId))
		return
	end

	if modeId == "training" or modeId == "pvp" then
		launchMatch(modeId, takePlayers(modeId))
		return
	end

	-- FFA: wait for fill timeout once minimum is met
	if not queue.fillDeadline then
		queue.fillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
		fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
			fillTimers[modeId] = nil
			if not MatchStateService.isArenaBusy() and getQueueSize(modeId) >= mode.minPlayers then
				launchMatch(modeId, takePlayers(modeId))
			else
				broadcastQueue(modeId)
			end
		end)
	end

	broadcastQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not queues[modeId] then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if MatchModes.get(modeId).minPlayers > 1 and #Players:GetPlayers() < MatchModes.get(modeId).minPlayers then
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			error = "Nicht genug Spieler online",
		})
		return
	end

	removeFromQueue(player, true)
	table.insert(queues[modeId].players, player)
	playerMode[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	broadcastQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player, false)
end

function MatchmakingService.onArenaFree()
	for modeId, _ in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	MatchStateService.onArenaFree(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
