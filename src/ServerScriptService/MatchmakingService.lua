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
local fillTimers = {}
local getActiveModeId

local function initQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end
end

local function getQueueCount(modeId)
	initQueue(modeId)
	return #queues[modeId].players
end

local function isPlayerInQueue(player)
	return playerQueue[player] ~= nil
end

local function buildStatusMessage(mode, count, status)
	if status == MatchmakingConfig.STATUS.PENDING then
		return "Arena belegt — du bist als Nächster dran"
	end
	if status == MatchmakingConfig.STATUS.STARTING then
		return "Match startet..."
	end
	if mode.id == "training" then
		return "Suche Trainings-Slot..."
	end
	if mode.id == "pvp" then
		return string.format("Warte auf Gegner (%d/2)", count)
	end
	if count < mode.minPlayers then
		return string.format("Warte auf Spieler (%d/%d)", count, mode.minPlayers)
	end
	return string.format("Warte auf weitere Spieler (%d/%d)", count, mode.maxPlayers)
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	local position = 0
	for i, queuedPlayer in queues[modeId].players do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = MatchmakingConfig.STATUS.WAITING
	if MatchStateService.isBusy() then
		status = MatchmakingConfig.STATUS.PENDING
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queued = count,
		needed = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		status = status,
		message = buildStatusMessage(mode, count, status),
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates(modeId)
	initQueue(modeId)
	for _, player in queues[modeId].players do
		sendQueueUpdate(player)
	end
end

local function cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		fillTimers[modeId] = nil
	end
end

local function clearPlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	initQueue(modeId)
	local queue = queues[modeId]
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players < MatchModes.get(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueueUpdates(modeId)
end

local function takePlayersForMatch(modeId)
	initQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue.players, mode.maxPlayers)
	local taken = {}

	for _ = 1, count do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end

	cancelFillTimer(modeId)
	broadcastQueueUpdates(modeId)
	return taken
end

local function markPlayersStarting(players)
	for _, player in players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				status = MatchmakingConfig.STATUS.STARTING,
				message = "Match startet...",
			})
		end
	end
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)

	if count < mode.minPlayers then
		return false
	end
	if mode.id == "training" or mode.id == "pvp" then
		return count >= mode.maxPlayers
	end
	if count >= mode.maxPlayers then
		return true
	end
	return fillTimers[modeId] == "ready"
end

local function requeuePlayers(modeId, players)
	initQueue(modeId)
	for _, player in players do
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(queues[modeId].players, player)
			playerQueue[player] = modeId
		end
	end
	broadcastQueueUpdates(modeId)
end

local function launchMatch(modeId)
	if MatchStateService.isBusy() then
		broadcastQueueUpdates(modeId)
		return false
	end
	if not canStartMatch(modeId) then
		return false
	end

	if not MatchStateService.tryAcquire() then
		broadcastQueueUpdates(modeId)
		return false
	end

	local players = takePlayersForMatch(modeId)
	if #players == 0 then
		MatchStateService.clearBusy()
		return false
	end

	markPlayersStarting(players)
	MatchReady:Fire({ mode = modeId, players = players })
	return true
end

function MatchmakingService.requeueFailedMatch(modeId, players)
	MatchStateService.clearBusy()
	requeuePlayers(modeId, players)
	tryStartMatch(modeId)
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		broadcastQueueUpdates(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)

	if mode.fillTimeout > 0 and count >= mode.minPlayers and count < mode.maxPlayers then
		if not fillTimers[modeId] then
			local token = {}
			fillTimers[modeId] = token
			task.delay(mode.fillTimeout, function()
				if fillTimers[modeId] ~= token then
					return
				end
				fillTimers[modeId] = "ready"
				launchMatch(modeId)
			end)
		end
	end

	launchMatch(modeId)
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getActiveModeId()
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	clearPlayerFromQueue(player)

	initQueue(modeId)
	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not isPlayerInQueue(player) then
		return
	end
	clearPlayerFromQueue(player)
	sendQueueUpdate(player)
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.onArenaFree()
	for modeId, _ in MatchModes.all() do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.isInQueue(player)
	return isPlayerInQueue(player)
end

function MatchmakingService.init(options)
	getActiveModeId = options.getActiveModeId

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	for modeId, _ in MatchModes.all() do
		initQueue(modeId)
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearPlayerFromQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
