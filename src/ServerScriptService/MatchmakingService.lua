--[[
	MatchmakingService — Queue pro Modus, MatchReady wenn genug Spieler + Arena frei.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReadyBindable

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil
local started = false

local function initQueues()
	for _, modeId in MatchModes.all() do
		queues[modeId] = {}
	end
end

local function getQueueSize(modeId)
	local count = 0
	for player, queuedMode in playerQueue do
		if queuedMode == modeId and player.Parent then
			count += 1
		end
	end
	return count
end

local function getQueuePosition(player, modeId)
	local position = 0
	for _, p in Players:GetPlayers() do
		if playerQueue[p] == modeId and p.Parent then
			position += 1
			if p == player then
				return position
			end
		end
	end
	return 0
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { status = "idle" }
	end

	return {
		status = status or "waiting",
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = getQueueSize(modeId),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = getQueuePosition(player, modeId),
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function sendQueueUpdate(player, modeId, status)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
end

local function broadcastQueueUpdates(modeId)
	for player, queuedMode in playerQueue do
		if queuedMode == modeId and player.Parent then
			sendQueueUpdate(player, modeId, "waiting")
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	broadcastQueueUpdates(modeId)

	local mode = MatchModes.get(modeId)
	if mode and getQueueSize(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
	end
end

local function collectMatchPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local list = {}
	for _, player in Players:GetPlayers() do
		if playerQueue[player] == modeId and player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(list, player)
			if #list >= mode.maxPlayers then
				break
			end
		end
	end
	return list
end

local function pullPlayersFromQueues(players)
	for _, player in players do
		playerQueue[player] = nil
	end
	for modeId in queues do
		broadcastQueueUpdates(modeId)
		clearFillTimer(modeId)
	end
end

local function notifyPending(players, modeId)
	for _, player in players do
		sendQueueUpdate(player, modeId, "pending")
	end
end

local function launchMatch(players, modeId)
	pendingMatch = nil
	pullPlayersFromQueues(players)
	MatchStateService.setBusy(true)

	for _, player in players do
		if HubService.leaveHubForArena then
			HubService.leaveHubForArena(player)
		end
		Remotes.QueueUpdate:FireClient(player, { status = "matched", modeId = modeId })
	end

	MatchReadyBindable:Fire({
		players = players,
		modeId = modeId,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	local players = collectMatchPlayers(modeId)
	if #players < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		pendingMatch = { modeId = modeId, players = players }
		notifyPending(players, modeId)
		return
	end

	launchMatch(players, modeId)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.maxPlayers or mode.maxPlayers <= mode.minPlayers then
		return
	end
	if fillTimers[modeId] then
		return
	end

	local timeout = MatchmakingConfig.FFA_FILL_TIMEOUT
	if modeId ~= "ffa" then
		return
	end

	fillTimers[modeId] = task.delay(timeout, function()
		fillTimers[modeId] = nil
		if getQueueSize(modeId) >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end
	if MatchStateService.isBusy() and HubService.getPhase(player) ~= "hub" then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)
	playerQueue[player] = modeId
	sendQueueUpdate(player, modeId, "waiting")
	broadcastQueueUpdates(modeId)

	local mode = MatchModes.get(modeId)
	local size = getQueueSize(modeId)
	if size >= mode.minPlayers then
		if modeId == "ffa" then
			if size >= mode.maxPlayers then
				tryStartMatch(modeId)
			else
				scheduleFillTimeout(modeId)
			end
		else
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		Remotes.QueueUpdate:FireClient(player, { status = "idle" })
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)

	if pendingMatch then
		local snapshot = pendingMatch
		pendingMatch = nil
		task.defer(function()
			if not MatchStateService.isBusy() then
				launchMatch(snapshot.players, snapshot.modeId)
			end
		end)
		return
	end

	for _, modeId in MatchModes.all() do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.start(remotes, bindables)
	if started then
		return
	end
	started = true

	Remotes = remotes
	MatchReadyBindable = bindables.MatchReady

	initQueues()

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
		removeFromQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
			if pendingMatch and not MatchStateService.isBusy() then
				local snapshot = pendingMatch
				pendingMatch = nil
				launchMatch(snapshot.players, snapshot.modeId)
			end
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
