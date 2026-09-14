local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes
local MatchReady
local ArenaFree

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillStartedAt = nil,
		}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players == 0 then
		queue.fillStartedAt = nil
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(player, status)
	local entry = playerQueue[player]
	if not entry then
		return { status = "idle" }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local position = 0
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		status = status or entry.status,
		modeId = entry.modeId,
		label = mode.label,
		position = position,
		queued = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = not GameMatchState.isArenaFree(),
	}
end

local function sendQueueUpdate(player, status)
	if player.Parent and Remotes.QueueUpdate then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, status))
	end
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function resolveModeId(modeId)
	if modeId == "auto" or modeId == nil then
		return MatchModes.defaultForPlayerCount(#Players:GetPlayers()).id
	end
	return modeId
end

local function collectReadyPlayers(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	for i = 1, math.min(count, #queue.players) do
		local player = queue.players[i]
		if player and player.Parent then
			table.insert(taken, player)
		end
	end
	return taken
end

local function removePlayersFromQueue(modeId, playerList)
	local queue = getQueue(modeId)
	for _, player in playerList do
		for i, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, i)
				break
			end
		end
		playerQueue[player] = nil
	end
	if #queue.players == 0 then
		queue.fillStartedAt = nil
	end
end

local function startMatch(modeId, playerList)
	pendingMatch = nil
	removePlayersFromQueue(modeId, playerList)

	if MatchReady then
		MatchReady:Fire(modeId, playerList)
	end
end

local function tryLaunchPending()
	if not pendingMatch or not GameMatchState.isArenaFree() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	startMatch(match.modeId, match.players)
	broadcastQueueUpdate(match.modeId)
end

local function queueMatch(modeId, playerList)
	if GameMatchState.isArenaFree() then
		startMatch(modeId, playerList)
	else
		pendingMatch = {
			modeId = modeId,
			players = playerList,
		}
		for _, player in playerList do
			if player.Parent then
				local entry = playerQueue[player]
				if entry then
					entry.status = "pending"
				end
				sendQueueUpdate(player, "pending")
			end
		end
	end
end

local function shouldStartQueue(mode, queue)
	if #queue.players < mode.minPlayers then
		return false
	end
	if #queue.players >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout <= 0 then
		return #queue.players >= mode.minPlayers
	end
	if not queue.fillStartedAt then
		queue.fillStartedAt = os.clock()
		return false
	end
	return os.clock() - queue.fillStartedAt >= mode.fillTimeout
end

local function processQueues()
	if pendingMatch then
		tryLaunchPending()
		if pendingMatch or not GameMatchState.isArenaFree() then
			return
		end
	end

	for _, mode in MatchModes.all() do
		local queue = getQueue(mode.id)
		if not shouldStartQueue(mode, queue) then
			continue
		end

		local count = math.min(#queue.players, mode.maxPlayers)
		local players = collectReadyPlayers(mode.id, count)
		if #players == 0 then
			continue
		end

		queueMatch(mode.id, players)
		broadcastQueueUpdate(mode.id)

		if pendingMatch or not GameMatchState.isArenaFree() then
			return
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false, "invalid_player"
	end

	local resolvedId = resolveModeId(modeId)
	local mode = MatchModes.get(resolvedId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(resolvedId)
	if #queue.players >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue.players, player)
	playerQueue[player] = {
		modeId = resolvedId,
		status = "queued",
	}

	if #queue.players >= mode.minPlayers and mode.fillTimeout > 0 and not queue.fillStartedAt then
		queue.fillStartedAt = os.clock()
	end

	sendQueueUpdate(player, "queued")
	broadcastQueueUpdate(resolvedId)
	processQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	sendQueueUpdate(player, "idle")

	if pendingMatch then
		for i, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				table.remove(pendingMatch.players, i)
				break
			end
		end
		if #pendingMatch.players == 0 then
			pendingMatch = nil
		end
	end

	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	tryLaunchPending()

	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.start(hubCallbacks)
	local remotesFolder, bindables = RemotesSetup.ensure()
	Remotes = remotesFolder
	MatchReady = bindables.MatchReady
	ArenaFree = bindables.ArenaFree

	if hubCallbacks and hubCallbacks.prepareForArena then
		MatchReady.Event:Connect(function(modeId, playerList)
			for _, player in playerList do
				hubCallbacks.prepareForArena(player)
			end
		end)
	end

	if ArenaFree then
		ArenaFree.Event:Connect(function()
			MatchmakingService.onArenaFreed()
		end)
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if started then
		return
	end
	started = true

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			processQueues()
		end
	end)
end

return MatchmakingService
