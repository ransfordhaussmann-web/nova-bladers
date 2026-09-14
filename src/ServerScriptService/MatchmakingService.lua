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
local playerToMode = {}
local pendingMatch = nil
local fillTimers = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end
	return queues[modeId]
end

local function isPlayerQueued(player)
	return playerToMode[player] ~= nil
end

local function buildQueuePayload(player)
	local modeId = playerToMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local status = "waiting"
	if pendingMatch and pendingMatch.modeId == modeId then
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
		queued = #queue.players,
		needed = mode.minPlayers,
		max = mode.maxPlayers,
		status = status,
	}

	if mode.fillTimeout and fillTimers[modeId] then
		payload.fillSecondsLeft = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
	end

	return payload
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if isPlayerQueued(player) then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerToMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, p in queue.players do
		if p == player then
			table.remove(queue.players, i)
			break
		end
	end
	playerToMode[player] = nil

	local mode = MatchModes.get(modeId)
	if mode and mode.fillTimeout and #queue.players < mode.minPlayers then
		clearFillTimer(modeId)
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			playerToMode[player] = nil
			table.insert(taken, player)
		end
	end
	clearFillTimer(modeId)
	return taken
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end

	if mode.maxPlayers and count >= mode.maxPlayers then
		return true
	end

	if mode.fillTimeout and fillTimers[modeId] then
		local timer = fillTimers[modeId]
		if os.clock() >= timer.endsAt then
			return true
		end
		return false
	end

	if not mode.fillTimeout then
		return count >= mode.minPlayers
	end

	return false
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end
	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = {
		endsAt = os.clock() + mode.fillTimeout,
		token = token,
	}

	task.delay(mode.fillTimeout, function()
		if not fillTimers[modeId] or fillTimers[modeId].token ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryFormMatch(modeId)
	end)

	broadcastQueueUpdates()
end

local function launchMatch(modeId, playerList)
	for _, player in playerList do
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = MatchModes.get(modeId).label,
			status = "starting",
		})
	end

	MatchReady:Fire({
		modeId = modeId,
		players = playerList,
	})
end

function MatchmakingService.tryFormMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if not canStartMode(modeId) then
		return
	end

	local queue = getQueue(modeId)
	local takeCount = math.min(#queue.players, mode.maxPlayers or #queue.players)
	local players = takePlayersFromQueue(modeId, takeCount)

	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = { modeId = modeId, players = players }
		broadcastQueueUpdates()
		return
	end

	pendingMatch = nil
	launchMatch(modeId, players)
	broadcastQueueUpdates()
end

function MatchmakingService.scanAllQueues()
	for _, mode in MatchModes.all() do
		MatchmakingService.tryFormMatch(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end

	removePlayerFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerToMode[player] = modeId

	local mode = MatchModes.get(modeId)
	if mode.fillTimeout and #queue.players >= mode.minPlayers then
		startFillTimer(modeId)
	end

	MatchmakingService.tryFormMatch(modeId)
	broadcastQueueUpdates()
end

function MatchmakingService.leaveQueue(player)
	if not isPlayerQueued(player) then
		return
	end

	removePlayerFromQueue(player)

	if pendingMatch then
		for i, p in pendingMatch.players do
			if p == player then
				table.remove(pendingMatch.players, i)
				if #pendingMatch.players < MatchModes.get(pendingMatch.modeId).minPlayers then
					for _, leftover in pendingMatch.players do
						MatchmakingService.joinQueue(leftover, pendingMatch.modeId)
					end
					pendingMatch = nil
				end
				break
			end
		end
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdates()
end

function MatchmakingService.onArenaFreed()
	if pendingMatch and #pendingMatch.players >= MatchModes.get(pendingMatch.modeId).minPlayers then
		local match = pendingMatch
		pendingMatch = nil
		launchMatch(match.modeId, match.players)
		broadcastQueueUpdates()
		return
	end

	MatchmakingService.scanAllQueues()
end

function MatchmakingService.getPlayerMode(player)
	return playerToMode[player]
end

function MatchmakingService.start()
	local _, bindables = RemotesSetup.ensure()
	Remotes = ReplicatedStorage.NovaBladers.Remotes
	MatchReady = bindables.MatchReady

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

	MatchStateService.onArenaIdle(function()
		MatchmakingService.onArenaFreed()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			broadcastQueueUpdates()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
