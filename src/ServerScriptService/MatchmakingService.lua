local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local remotes
local matchReadyBindable
local arenaFreeBindable

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillDeadline = {}
local pendingMatch = nil
local started = false
local heartbeatTask = nil

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil

	local mode = MatchModes.get(modeId)
	if mode and #getQueue(modeId) < mode.minPlayers then
		fillDeadline[modeId] = nil
	end
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local waiting = #queue
	local needed = mode.maxPlayers
	local status = "waiting"

	if pendingMatch then
		for _, p in pendingMatch.players do
			if p == player then
				status = "pending"
				break
			end
		end
	end

	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersWaiting = waiting,
		playersNeeded = needed,
		minPlayers = mode.minPlayers,
		status = status,
	}

	local deadline = fillDeadline[modeId]
	if deadline and mode.fillTimeout then
		payload.fillTimeout = math.max(0, math.ceil(deadline - os.clock()))
	end

	return payload
end

local function sendQueueUpdate(player)
	if not remotes or not remotes.QueueUpdate then
		return
	end
	if player.Parent then
		remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates(modeId)
	local seen = {}
	if modeId then
		for _, player in getQueue(modeId) do
			seen[player] = true
			sendQueueUpdate(player)
		end
	end

	if pendingMatch then
		for _, player in pendingMatch.players do
			if not seen[player] then
				sendQueueUpdate(player)
			end
		end
	end
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	if count < mode.minPlayers then
		return nil
	end

	local take = math.min(count, mode.maxPlayers)
	local ready = {}
	for i = 1, take do
		table.insert(ready, queue[i])
	end
	return ready
end

local function removePlayersFromQueueList(modeId, readyPlayers)
	local queue = getQueue(modeId)
	for _, player in readyPlayers do
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end
	fillDeadline[modeId] = nil
end

local function releasePlayers(readyPlayers)
	for _, player in readyPlayers do
		playerMode[player] = nil
		sendQueueUpdate(player)
	end
end

local function launchMatch(modeId, readyPlayers)
	removePlayersFromQueueList(modeId, readyPlayers)

	for _, player in readyPlayers do
		if HubService.getPhase(player) == "hub" then
			HubService.leaveHubForArena(player)
		end
	end

	GameMatchState.setArenaBusy(true)
	matchReadyBindable:Fire(readyPlayers)
	releasePlayers(readyPlayers)
	broadcastQueueUpdates(modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local count = #queue
	if count < mode.minPlayers then
		return
	end

	if mode.fillTimeout and not fillDeadline[modeId] then
		fillDeadline[modeId] = os.clock() + mode.fillTimeout
	end

	local readyNow = false
	if count >= mode.maxPlayers then
		readyNow = true
	elseif mode.startImmediately and count >= mode.minPlayers then
		readyNow = true
	elseif not mode.fillTimeout and count >= mode.minPlayers then
		readyNow = true
	elseif fillDeadline[modeId] and os.clock() >= fillDeadline[modeId] then
		readyNow = true
	end

	if not readyNow then
		broadcastQueueUpdates(modeId)
		return
	end

	local readyPlayers = collectReadyPlayers(modeId)
	if not readyPlayers then
		return
	end

	if GameMatchState.isArenaBusy() then
		pendingMatch = { modeId = modeId, players = readyPlayers }
		removePlayersFromQueueList(modeId, readyPlayers)
		for _, player in readyPlayers do
			sendQueueUpdate(player)
		end
		return
	end

	launchMatch(modeId, readyPlayers)
end

local function processPendingMatch()
	if not pendingMatch or GameMatchState.isArenaBusy() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	launchMatch(match.modeId, match.players)
end

local function queueHeartbeat()
	for modeId, mode in pairs(MatchModes) do
		if typeof(mode) == "table" and mode.id then
			local queue = getQueue(modeId)
			if #queue >= mode.minPlayers and mode.fillTimeout then
				tryStartMatch(modeId)
			end
		end
	end
	processPendingMatch()
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerMode[player] = modeId

	tryStartMatch(modeId)
	sendQueueUpdate(player)
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		sendQueueUpdate(player)
		return
	end

	local modeId = playerMode[player]

	if pendingMatch then
		for i, p in pendingMatch.players do
			if p == player then
				table.remove(pendingMatch.players, i)
				if #pendingMatch.players == 0 then
					pendingMatch = nil
				end
				break
			end
		end
	end

	removeFromQueue(player)
	broadcastQueueUpdates(modeId)
	sendQueueUpdate(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.start(remotesFolder, bindablesFolder)
	if started then
		return
	end
	started = true

	remotes = remotesFolder
	matchReadyBindable = bindablesFolder.MatchReady
	arenaFreeBindable = bindablesFolder.ArenaFree

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	arenaFreeBindable.Event:Connect(function()
		GameMatchState.setArenaBusy(false)
		processPendingMatch()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	heartbeatTask = task.spawn(function()
		while started do
			queueHeartbeat()
			task.wait(MatchmakingConfig.QUEUE_TICK)
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
