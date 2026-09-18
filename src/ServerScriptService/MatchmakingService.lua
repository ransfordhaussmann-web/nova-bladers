local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local QueueJoin, QueueLeave, QueueUpdate
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local handlers = {}

local function getQueueList(modeId)
	return queues[modeId]
end

local function modeFromId(modeId)
	return MatchModes.get(modeId)
end

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function removeFromQueueList(player, modeId)
	local queue = getQueueList(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
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

local function getQueueNames(modeId)
	local names = {}
	for _, queuedPlayer in getQueueList(modeId) do
		if isValidPlayer(queuedPlayer) then
			table.insert(names, queuedPlayer.Name)
		end
	end
	return names
end

local function buildUpdatePayload(player, modeId, status, extra)
	local mode = modeFromId(modeId)
	local queue = getQueueList(modeId)
	local count = 0
	for _, queuedPlayer in queue do
		if isValidPlayer(queuedPlayer) then
			count += 1
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		status = status,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		players = getQueueNames(modeId),
		fillSeconds = extra and extra.fillSeconds,
		pendingArena = extra and extra.pendingArena or false,
	}
end

local function sendQueueUpdate(player, modeId, status, extra)
	if not isValidPlayer(player) then
		return
	end
	QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId, status, extra))
end

local function broadcastQueue(modeId, status, extra)
	for _, queuedPlayer in getQueueList(modeId) do
		sendQueueUpdate(queuedPlayer, modeId, status, extra)
	end
end

local function pruneQueue(modeId)
	local queue = getQueueList(modeId)
	for i = #queue, 1, -1 do
		if not isValidPlayer(queue[i]) then
			table.remove(queue, i)
		end
	end
end

local function leaveQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueueList(player, modeId)
	playerQueue[player] = nil
	clearFillTimer(modeId)

	if not silent then
		sendQueueUpdate(player, modeId, "idle")
	end
	broadcastQueue(modeId, MatchStateService.isBusy() and "pending" or "waiting")
end

local function preparePlayers(modeId)
	pruneQueue(modeId)
	local roster = {}
	for _, queuedPlayer in getQueueList(modeId) do
		if isValidPlayer(queuedPlayer) then
			table.insert(roster, queuedPlayer)
		end
	end
	return roster
end

local function startMatch(modeId, roster)
	for _, player in roster do
		playerQueue[player] = nil
	end
	queues[modeId] = {}
	clearFillTimer(modeId)

	MatchStateService.setBusy(true)

	if handlers.leaveHubForArena then
		for _, player in roster do
			handlers.leaveHubForArena(player)
		end
	end

	MatchReady:Fire(modeId, roster)
end

local function tryStartMatch(modeId)
	local mode = modeFromId(modeId)
	if not mode then
		return
	end

	local roster = preparePlayers(modeId)
	local count = #roster
	if count < mode.minPlayers then
		return
	end

	if count > mode.maxPlayers then
		while #roster > mode.maxPlayers do
			table.remove(roster)
		end
	end

	if MatchStateService.isBusy() then
		broadcastQueue(modeId, "pending", { pendingArena = true })
		return
	end

	broadcastQueue(modeId, "starting")
	startMatch(modeId, roster)
end

local function scheduleFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token
	local deadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT

	task.spawn(function()
		while fillTimers[modeId] == token do
			local remaining = math.max(0, math.ceil(deadline - os.clock()))
			broadcastQueue(modeId, MatchStateService.isBusy() and "pending" or "waiting", {
				fillSeconds = remaining,
				pendingArena = MatchStateService.isBusy(),
			})
			if os.clock() >= deadline then
				break
			end
			task.wait(MatchmakingConfig.QUEUE_TICK)
		end

		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function onQueueChanged(modeId)
	local mode = modeFromId(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local count = #getQueueList(modeId)
	local status = MatchStateService.isBusy() and "pending" or "waiting"

	if mode.instant and count >= mode.minPlayers then
		tryStartMatch(modeId)
		return
	end

	if count >= mode.maxPlayers then
		clearFillTimer(modeId)
		tryStartMatch(modeId)
		return
	end

	if modeId == "ffa" and count >= mode.minPlayers then
		scheduleFillTimer(modeId)
	else
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId, status, {
		pendingArena = MatchStateService.isBusy(),
	})
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return
	end

	local mode = modeFromId(modeId)
	if not mode then
		return
	end

	if handlers.getPhase and handlers.getPhase(player) ~= "hub" then
		return
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return
		end
		leaveQueue(player, true)
	end

	table.insert(getQueueList(modeId), player)
	playerQueue[player] = modeId

	local status = MatchStateService.isBusy() and "pending" or "waiting"
	sendQueueUpdate(player, modeId, status, { pendingArena = MatchStateService.isBusy() })
	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	local modeId = playerQueue[player]
	leaveQueue(player)
	onQueueChanged(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(newHandlers)
	handlers = newHandlers or {}
	Remotes, Bindables = RemotesSetup.ensure()
	QueueJoin = Remotes.QueueJoin
	QueueLeave = Remotes.QueueLeave
	QueueUpdate = Remotes.QueueUpdate
	MatchReady = Bindables.MatchReady

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		for modeId, _ in queues do
			pruneQueue(modeId)
			if #getQueueList(modeId) > 0 then
				onQueueChanged(modeId)
			end
		end
	end)
end

return MatchmakingService
