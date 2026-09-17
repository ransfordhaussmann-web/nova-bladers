local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local callbacks = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			pending = false,
			fillDeadline = nil,
		}
	end
	return queues[modeId]
end

local function queueCount(modeId)
	return #getQueue(modeId).players
end

local function buildUpdatePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players
	local fillSeconds

	if queue.fillDeadline then
		fillSeconds = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		min = mode.minPlayers,
		max = mode.maxPlayers,
		fillSeconds = fillSeconds,
		pending = queue.pending and MatchStateService.isArenaBusy(),
	}
end

local function sendQueueClear(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if mode.fillTimeout > 0 and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true
	end

	if mode.fillTimeout == 0 and count >= mode.minPlayers then
		return true
	end

	return false
end

local function leaveQueueInternal(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue.players < MatchModes.get(modeId).minPlayers then
		queue.fillDeadline = nil
		queue.pending = false
		clearFillTimer(modeId)
	end

	if not silent and player.Parent then
		sendQueueClear(player)
	end

	broadcastQueue(modeId)
end

local function popPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local matchPlayers = {}

	for i = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(matchPlayers, queue.players[1])
		playerQueue[queue.players[1]] = nil
		table.remove(queue.players, 1)
	end

	queue.fillDeadline = nil
	queue.pending = false
	clearFillTimer(modeId)
	return matchPlayers
end

local function tryStartMatch(modeId)
	if not canStartMatch(modeId) then
		return
	end

	local queue = getQueue(modeId)
	if not MatchStateService.tryReserveArena() then
		queue.pending = true
		broadcastQueue(modeId)
		return
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers == 0 then
		MatchStateService.setArenaBusy(false)
		return
	end

	for _, player in matchPlayers do
		sendQueueClear(player)
		if callbacks.onMatchStarting then
			callbacks.onMatchStarting(player, modeId)
		end
	end

	Bindables.MatchReady:Fire({
		players = matchPlayers,
		modeId = modeId,
	})

	for modeKey, _ in pairs(queues) do
		broadcastQueue(modeKey)
	end
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	clearFillTimer(modeId)
	local queue = getQueue(modeId)
	queue.fillDeadline = os.clock() + mode.fillTimeout

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		leaveQueueInternal(player, true)
	end

	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	local queue = getQueue(modeId)
	if #queue.players >= MatchModes.get(modeId).maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	if #queue.players == mode.minPlayers and mode.fillTimeout > 0 then
		scheduleFillTimer(modeId)
	end

	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	leaveQueueInternal(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFree()
	for modeId, _ in pairs(queues) do
		local queue = getQueue(modeId)
		if queue.pending or canStartMatch(modeId) then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.init(options)
	callbacks = options or {}

	MatchStateService.onArenaFree(function()
		MatchmakingService.onArenaFree()
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
