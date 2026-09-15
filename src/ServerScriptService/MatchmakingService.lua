local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes = nil
local bindables = nil
local onMatchStart = nil

local queues = {}
local playerQueue = {}
local tickConnection = nil

local function initQueues()
	for modeId, mode in MatchModes do
		if typeof(mode) == "table" and mode.id then
			queues[modeId] = {
				players = {},
				fillDeadline = nil,
			}
		end
	end
end

local function buildStatusMessage(mode, queued, needed, status)
	if status == "pending" then
		return "Arena belegt — du bist als Nächstes dran"
	end
	if status == "starting" then
		return "Match startet..."
	end
	if queued >= needed then
		return string.format("Fast bereit (%d/%d)", queued, mode.maxPlayers)
	end
	return string.format("Warte auf Spieler (%d/%d)", queued, needed)
end

local function sendQueueUpdate(player, payload)
	if player.Parent and remotes and remotes.QueueUpdate then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function clearQueueUpdate(player)
	sendQueueUpdate(player, { inQueue = false })
end

local function getQueuePosition(modeId, player)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			return index
		end
	end
	return 0
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	local mode = MatchModes.get(modeId)
	local queued = #queue.players
	local arenaBusy = MatchStateService.isArenaBusy()
	local status = arenaBusy and "pending" or "waiting"

	if queued >= mode.minPlayers and not arenaBusy then
		if modeId == "ffa" and queue.fillDeadline and os.clock() < queue.fillDeadline then
			status = "waiting"
		elseif queued >= mode.minPlayers then
			status = "starting"
		end
	end

	for _, player in queue.players do
		sendQueueUpdate(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = mode.label,
			position = getQueuePosition(modeId, player),
			queued = queued,
			needed = mode.minPlayers,
			maxPlayers = mode.maxPlayers,
			status = status,
			message = buildStatusMessage(mode, queued, mode.minPlayers, status),
			arenaBusy = arenaBusy,
		})
	end
end

local function removeFromQueue(player, silent)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	if queue then
		for index, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, index)
				break
			end
		end
		if #queue.players < MatchModes.get(entry.modeId).minPlayers then
			queue.fillDeadline = nil
		end
	end

	playerQueue[player] = nil

	if not silent then
		clearQueueUpdate(player)
	end

	if queue then
		broadcastQueue(entry.modeId)
	end
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	queue.fillDeadline = nil
	return taken
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue then
		return false
	end

	local count = #queue.players
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "ffa" then
		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
		end
		return os.clock() >= queue.fillDeadline
	end
	return count >= mode.minPlayers
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue or not canStartMode(modeId) then
		return
	end

	local players = takePlayers(modeId, mode.maxPlayers)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queue.players, player)
			playerQueue[player] = { modeId = modeId }
		end
		return
	end

	for _, player in players do
		sendQueueUpdate(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = mode.label,
			status = "starting",
			message = "Match startet...",
		})
	end

	if onMatchStart then
		onMatchStart(players, modeId)
	end

	for otherModeId, otherQueue in queues do
		if #otherQueue.players > 0 then
			broadcastQueue(otherModeId)
		end
	end
end

local function checkAllQueues()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return
	end
	if playerQueue[player] then
		removeFromQueue(player, true)
	end

	local resolvedId = MatchModes.resolve(modeId, #Players:GetPlayers())
	local queue = queues[resolvedId]
	if not queue then
		return
	end

	table.insert(queue.players, player)
	playerQueue[player] = { modeId = resolvedId }

	local mode = MatchModes.get(resolvedId)
	if #queue.players >= mode.minPlayers and mode.id == "ffa" and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	end

	broadcastQueue(resolvedId)
	tryStartMatch(resolvedId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player, false)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.onArenaAvailable()
	checkAllQueues()
	for modeId, queue in queues do
		if #queue.players > 0 then
			broadcastQueue(modeId)
		end
	end
end

function MatchmakingService.start(deps)
	remotes = deps.remotes
	bindables = deps.bindables
	onMatchStart = deps.onMatchStart

	initQueues()

	if tickConnection then
		tickConnection:Disconnect()
	end

	tickConnection = game:GetService("RunService").Heartbeat:Connect(function()
		for modeId, queue in queues do
			if queue.fillDeadline and os.clock() >= queue.fillDeadline then
				tryStartMatch(modeId)
			end
		end
	end)

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "auto"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
