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
local playerEntry = {}
local fillTimers = {}
local callbacks = {}
local tickConnection

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isValidQueuedPlayer(player)
	return player and player.Parent and callbacks.getPhase(player) == "hub"
end

local function getQueuePlayers(modeId)
	local queue = queues[modeId]
	if not queue then
		return {}
	end

	local valid = {}
	for _, player in queue.players do
		if isValidQueuedPlayer(player) then
			table.insert(valid, player)
		end
	end
	queue.players = valid
	return valid
end

local function buildStatusText(mode, queueSize, status)
	if status == "pending" then
		return "Arena belegt — Match startet gleich..."
	end
	if queueSize < mode.minPlayers then
		return string.format("Warte auf Spieler (%d/%d)...", queueSize, mode.minPlayers)
	end
	if mode.fillTimeout > 0 and queueSize < mode.maxPlayers then
		return string.format("Lobby füllt sich (%d/%d)...", queueSize, mode.maxPlayers)
	end
	return "Match startet..."
end

local function sendQueueUpdate(player)
	if not Remotes then
		return
	end

	local entry = playerEntry[player]
	if not entry then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local mode = getMode(entry.modeId)
	if not mode then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local queueSize = #getQueuePlayers(entry.modeId)
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		modeId = mode.id,
		modeLabel = mode.label,
		queueSize = queueSize,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = entry.status,
		statusText = buildStatusText(mode, queueSize, entry.status),
	})
end

local function broadcastQueueUpdate(modeId)
	for player, entry in playerEntry do
		if entry.modeId == modeId then
			sendQueueUpdate(player)
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId] = nil
	end
end

local function removePlayerFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	if queue then
		for i, queued in queue.players do
			if queued == player then
				table.remove(queue.players, i)
				break
			end
		end
	end

	playerEntry[player] = nil
	sendQueueUpdate(player)
	broadcastQueueUpdate(entry.modeId)
end

local function takePlayersForMatch(modeId, count)
	local players = getQueuePlayers(modeId)
	local picked = {}
	for i = 1, math.min(count, #players) do
		table.insert(picked, players[i])
	end

	for _, player in picked do
		removePlayerFromQueue(player)
	end

	clearFillTimer(modeId)
	return picked
end

local function launchMatch(modeId, players)
	for _, player in players do
		if callbacks.leaveHubForArena then
			callbacks.leaveHubForArena(player)
		end
	end

	MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local players = getQueuePlayers(modeId)
	local count = #players

	if count < mode.minPlayers then
		clearFillTimer(modeId)
		return
	end

	if mode.fillTimeout > 0 and count < mode.maxPlayers then
		if not fillTimers[modeId] then
			fillTimers[modeId] = os.clock() + mode.fillTimeout
		elseif os.clock() < fillTimers[modeId] then
			return
		end
	else
		clearFillTimer(modeId)
	end

	local matchCount = math.min(count, mode.maxPlayers)
	local picked = takePlayersForMatch(modeId, matchCount)
	if #picked < mode.minPlayers then
		for _, player in picked do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	if MatchStateService.isArenaBusy() then
		for _, player in picked do
			playerEntry[player] = {
				modeId = modeId,
				status = "pending",
			}
			local queue = queues[modeId]
			table.insert(queue.players, player)
		end
		broadcastQueueUpdate(modeId)
		return
	end

	launchMatch(modeId, picked)
end

local function onQueueTick()
	for modeId in MatchModes do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	if callbacks.getPhase(player) ~= "hub" then
		return
	end

	removePlayerFromQueue(player)

	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end

	playerEntry[player] = {
		modeId = modeId,
		status = "waiting",
	}
	table.insert(queues[modeId].players, player)

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	removePlayerFromQueue(player)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onArenaFree()
	for modeId in MatchModes do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.init(options)
	callbacks = options or {}

	local bindables
	Remotes, bindables = RemotesSetup.ensure()
	MatchReady = bindables.MatchReady

	for modeId in MatchModes do
		queues[modeId] = { players = {} }
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if tickConnection then
		tickConnection:Disconnect()
	end

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			onQueueTick()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
