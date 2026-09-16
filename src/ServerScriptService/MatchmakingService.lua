local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function getQueueList(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueueList(modeId, player)
	local queue = getQueueList(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
	return token
end

local function buildQueuePayload(player, modeId, status, message)
	local mode = getMode(modeId)
	local queue = getQueueList(modeId)
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		inQueue = playerQueue[player] ~= nil,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = position,
		queueSize = #queue,
		required = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status or "waiting",
		message = message,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function sendQueueUpdate(player, modeId, status, message)
	if player.Parent and Remotes then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status, message))
	end
end

local function broadcastQueue(modeId)
	local queue = getQueueList(modeId)
	local arenaBusy = MatchStateService.isBusy()
	for _, player in queue do
		local status = arenaBusy and "pending" or "waiting"
		local message = arenaBusy and "Arena belegt — du bist als Nächstes dran" or nil
		sendQueueUpdate(player, modeId, status, message)
	end
end

local function cancelFillTimer(modeId)
	clearFillTimer(modeId)
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	removeFromQueueList(modeId, player)

	local queue = getQueueList(modeId)
	if #queue == 0 then
		cancelFillTimer(modeId)
	end

	sendQueueUpdate(player, modeId, "left", "Queue verlassen")
	broadcastQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		sendQueueUpdate(player, modeId, MatchStateService.isBusy() and "pending" or "waiting")
		return
	end

	MatchmakingService.leaveQueue(player)

	table.insert(getQueueList(modeId), player)
	playerQueue[player] = modeId

	if modeId == "ffa" and #getQueueList(modeId) >= 1 then
		startFillTimer(modeId)
	end

	local status = MatchStateService.isBusy() and "pending" or "waiting"
	local message = MatchStateService.isBusy() and "Arena belegt — du bist als Nächstes dran" or nil
	sendQueueUpdate(player, modeId, status, message)
	broadcastQueue(modeId)

	MatchmakingService.tryStartMatch(modeId)
end

local function takePlayersFromQueue(modeId, mode)
	local queue = getQueueList(modeId)
	local count = #queue
	if count < mode.minPlayers then
		return nil
	end

	if modeId == "ffa" and count < mode.maxPlayers and fillTimers[modeId] then
		return nil
	end

	local players = {}
	for index = 1, math.min(count, mode.maxPlayers) do
		table.insert(players, queue[index])
	end

	for _, player in players do
		playerQueue[player] = nil
		removeFromQueueList(modeId, player)
	end
	cancelFillTimer(modeId)

	return players
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queue = getQueueList(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" and #queue < mode.maxPlayers and fillTimers[modeId] then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local players = takePlayersFromQueue(modeId, mode)
	if not players then
		return
	end

	MatchmakingService.launchMatch(modeId, players)
end

function MatchmakingService.launchMatch(modeId, players)
	local activePlayers = {}
	for _, player in players do
		if player.Parent then
			table.insert(activePlayers, player)
		end
	end

	local mode = getMode(modeId)
	if not mode or #activePlayers < mode.minPlayers then
		for _, player in activePlayers do
			if not playerQueue[player] then
				table.insert(getQueueList(modeId), player)
				playerQueue[player] = modeId
			end
		end
		broadcastQueue(modeId)
		return
	end

	for _, player in activePlayers do
		sendQueueUpdate(player, modeId, "starting", "Match startet...")
	end

	MatchReady:Fire(activePlayers, modeId)
end

function MatchmakingService.start(deps)
	local remotes, bindables = RemotesSetup.ensure()
	Remotes = deps.remotes or remotes
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		if deps.getPhase and deps.getPhase(player) ~= "hub" then
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

	MatchStateService.onArenaFree(function()
		for modeId, _ in MatchModes do
			MatchmakingService.tryStartMatch(modeId)
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
