local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes
local MatchReady
local ArenaFree

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillStartedAt = {}
local pendingMatch = nil
local started = false

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function removeFromList(list, player)
	for index, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, index)
			return true
		end
	end
	return false
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local list = queues[modeId]
	local position = 0
	for index, queuedPlayer in list do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local payload = {
		inQueue = position > 0,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queued = #list,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		arenaBusy = GameMatchState.isArenaBusy(),
	}

	if modeId == "ffa" and ffaFillStartedAt[modeId] and #list >= mode.minPlayers then
		local elapsed = os.clock() - ffaFillStartedAt[modeId]
		payload.fillTimeout = mode.fillTimeout
		payload.fillRemaining = math.max(0, math.ceil(mode.fillTimeout - elapsed))
	end

	if payload.status == "pending" then
		payload.message = "Arena belegt — du bist als Nächstes dran"
	elseif payload.inQueue and modeId == "ffa" and #list < mode.minPlayers then
		payload.message = string.format("Warte auf Spieler (%d/%d)", #list, mode.minPlayers)
	elseif payload.inQueue and modeId == "pvp" then
		payload.message = string.format("Warte auf Gegner (%d/%d)", #list, mode.minPlayers)
	elseif payload.inQueue then
		payload.message = "Match wird vorbereitet..."
	else
		payload.message = ""
	end

	return payload
end

local function sendQueueUpdate(player, modeId, status)
	if not isValidPlayer(player) or not Remotes then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] do
		if isValidPlayer(player) then
			sendQueueUpdate(player, modeId)
		end
	end
end

local function clearPlayerQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromList(queues[modeId], player)
	playerQueue[player] = nil

	if modeId == "ffa" and getQueueSize("ffa") < MatchModes.ffa.minPlayers then
		ffaFillStartedAt.ffa = nil
	end

	sendQueueUpdate(player, modeId, "left")
	broadcastQueue(modeId)
end

local function resolveQuickMatchMode()
	local count = #Players:GetPlayers()
	if count >= MatchModes.ffa.minPlayers then
		return "ffa"
	elseif count >= MatchModes.pvp.minPlayers then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.getQuickMatchMode()
	return resolveQuickMatchMode()
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false
	end

	if modeId == "quick" then
		modeId = resolveQuickMatchMode()
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player, modeId)
		return true
	end

	clearPlayerQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if modeId == "ffa" and getQueueSize("ffa") >= mode.minPlayers and not ffaFillStartedAt.ffa then
		ffaFillStartedAt.ffa = os.clock()
	end

	sendQueueUpdate(player, modeId)
	broadcastQueue(modeId)
	MatchmakingService.processQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if pendingMatch then
		for index, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				table.remove(pendingMatch.players, index)
				sendQueueUpdate(player, pendingMatch.modeId, "left")
				break
			end
		end
		if pendingMatch and #pendingMatch.players == 0 then
			pendingMatch = nil
		end
	end

	if not playerQueue[player] then
		sendQueueUpdate(player, nil, "left")
		return
	end
	clearPlayerQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

local function popPlayers(modeId, count)
	local picked = {}
	local list = queues[modeId]
	for _ = 1, count do
		local player = table.remove(list, 1)
		if isValidPlayer(player) then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	GameMatchState.setArenaBusy(true)
	pendingMatch = nil

	for _, queuedPlayer in playerList do
		sendQueueUpdate(queuedPlayer, modeId, "starting")
	end

	MatchReady:Fire(modeId, playerList)
end

local function tryLaunchMatch(modeId, playerList)
	if #playerList == 0 then
		return false
	end

	if GameMatchState.isArenaBusy() then
		queuePendingMatch(modeId, playerList)
		return true
	end

	startMatch(modeId, playerList)
	return true
end

local function queuePendingMatch(modeId, playerList)
	pendingMatch = {
		modeId = modeId,
		players = playerList,
	}
	for _, player in playerList do
		sendQueueUpdate(player, modeId, "pending")
	end
end

function MatchmakingService.processQueues()
	if not GameMatchState.isArenaBusy() and pendingMatch then
		startMatch(pendingMatch.modeId, pendingMatch.players)
		return
	end

	if pendingMatch then
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		local mode = MatchModes.get(modeId)
		local size = getQueueSize(modeId)
		if size == 0 then
			continue
		end

		if modeId == "training" and size >= mode.minPlayers then
			tryLaunchMatch(modeId, popPlayers(modeId, mode.minPlayers))
			return
		end

		if modeId == "pvp" and size >= mode.minPlayers then
			tryLaunchMatch(modeId, popPlayers(modeId, mode.minPlayers))
			return
		end

		if modeId == "ffa" then
			if size >= mode.maxPlayers then
				ffaFillStartedAt.ffa = nil
				tryLaunchMatch(modeId, popPlayers(modeId, mode.maxPlayers))
				return
			end

			if size >= mode.minPlayers and ffaFillStartedAt.ffa then
				local elapsed = os.clock() - ffaFillStartedAt.ffa
				if elapsed >= mode.fillTimeout then
					ffaFillStartedAt.ffa = nil
					tryLaunchMatch(modeId, popPlayers(modeId, size))
					return
				end
			end
		end
	end
end

local function onArenaFree()
	GameMatchState.setArenaBusy(false)
	task.defer(MatchmakingService.processQueues)
end

local function onPlayerRemoving(player)
	clearPlayerQueue(player)

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

function MatchmakingService.start(remotes, bindables)
	if started then
		return
	end
	started = true

	Remotes = remotes
	MatchReady = bindables.MatchReady
	ArenaFree = bindables.ArenaFree

	ArenaFree.Event:Connect(onArenaFree)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "quick"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			MatchmakingService.processQueues()
		end
	end)
end

return MatchmakingService
