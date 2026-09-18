local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillStartedAt = {}
local pendingMatch = nil
local callbacks = {}

local function clearPlayerMatchmaking(player)
	playerMode[player] = nil
	if pendingMatch then
		for index, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				table.remove(pendingMatch.players, index)
				break
			end
		end
		if #pendingMatch.players == 0 then
			pendingMatch = nil
		end
	end
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	clearPlayerMatchmaking(player)

	if getQueueSize(modeId) < MatchModes.get(modeId).minPlayers then
		fillStartedAt[modeId] = nil
	end
end

local function isPendingPlayer(player)
	if not pendingMatch then
		return false
	end
	for _, pendingPlayer in pendingMatch.players do
		if pendingPlayer == player then
			return true
		end
	end
	return false
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId and pendingMatch then
		for _, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				modeId = pendingMatch.modeId
				break
			end
		end
	end
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local status = isPendingPlayer(player) and "pending" or "waiting"
	local queueSize = #queue
	if isPendingPlayer(player) and pendingMatch then
		queueSize = #pendingMatch.players
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = queueSize,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		if playerMode[player] or isPendingPlayer(player) then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if isValidPlayer(player) then
			playerMode[player] = modeId
			table.insert(taken, player)
		end
	end
	fillStartedAt[modeId] = nil
	return taken
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if callbacks.onMatchStarting then
		callbacks.onMatchStarting(playerList, modeId)
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(playerList, modeId)

	for _, player in playerList do
		playerMode[player] = nil
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	pendingMatch = nil
end

local function tryLaunchPending()
	if not pendingMatch or MatchStateService.isArenaBusy() then
		return
	end

	local snapshot = pendingMatch
	pendingMatch = nil
	launchMatch(snapshot.modeId, snapshot.players)
end

local function shouldStart(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = #queue

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "training" then
		return count >= 1
	end
	if modeId == "pvp" then
		return count >= 2
	end
	if modeId == "ffa" then
		local startedAt = fillStartedAt[modeId]
		if startedAt and os.clock() - startedAt >= MatchmakingConfig.FFA_FILL_TIMEOUT then
			return true
		end
	end
	return false
end

local function tryStartMode(modeId)
	if not shouldStart(modeId) then
		return
	end

	local mode = MatchModes.get(modeId)
	local count = math.min(getQueueSize(modeId), mode.maxPlayers)
	local players = takePlayersFromQueue(modeId, count)

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = players,
		}
		broadcastQueueUpdate()
		return
	end

	launchMatch(modeId, players)
end

local function tryStartAll()
	for modeId in queues do
		tryStartMode(modeId)
		if pendingMatch or MatchStateService.isArenaBusy() then
			break
		end
	end
end

local function joinQueue(player, modeId)
	if not isValidPlayer(player) or not MatchModes.get(modeId) then
		return
	end
	if callbacks.canJoinQueue and not callbacks.canJoinQueue(player) then
		return
	end

	removeFromQueue(player)

	local queue = queues[modeId]
	table.insert(queue, player)
	playerMode[player] = modeId

	local mode = MatchModes.get(modeId)
	if getQueueSize(modeId) >= mode.minPlayers and modeId == "ffa" and not fillStartedAt[modeId] then
		fillStartedAt[modeId] = os.clock()
	end

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	tryStartMode(modeId)
end

local function leaveQueue(player)
	if not playerMode[player] and not isPendingPlayer(player) then
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.init(options)
	callbacks = options or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		tryLaunchPending()
		tryStartAll()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			for modeId in queues do
				if fillStartedAt[modeId] and shouldStart(modeId) then
					tryStartMode(modeId)
				end
			end
			broadcastQueueUpdate()
		end
	end)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

return MatchmakingService
