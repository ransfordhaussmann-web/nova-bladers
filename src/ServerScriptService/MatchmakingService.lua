local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(ReplicatedStorage.NovaBladers.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local fillToken = {}
local pendingMode = nil
local started = false

local callbacks = {}

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function removeFromList(list, player)
	for i = #list, 1, -1 do
		if list[i] == player then
			table.remove(list, i)
		end
	end
end

local function getQueue(modeId)
	return queues[modeId] or queues.training
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	for i = #queue, 1, -1 do
		if not isValidPlayer(queue[i]) then
			playerMode[queue[i]] = nil
			table.remove(queue, i)
		end
	end
end

local function cancelFillTimer(modeId)
	fillToken[modeId] = (fillToken[modeId] or 0) + 1
	fillTimers[modeId] = nil
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	pruneQueue(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local position = 0
	for i, queued in queue do
		if queued == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif mode.waitForFill and count >= mode.minPlayers and fillTimers[modeId] then
		status = "filling"
	end

	return {
		inQueue = position > 0,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queued = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function fireQueueUpdate(player)
	if not isValidPlayer(player) then
		return
	end
	local modeId = playerMode[player]
	if modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	else
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function broadcastQueueUpdates(modeId)
	pruneQueue(modeId)
	for _, player in getQueue(modeId) do
		fireQueueUpdate(player)
	end
end

local function popPlayers(modeId, count)
	pruneQueue(modeId)
	local queue = getQueue(modeId)
	local picked = {}
	local take = math.min(count, #queue)
	for _ = 1, take do
		local player = table.remove(queue, 1)
		if isValidPlayer(player) then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function launchMatchNow(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	if #getQueue(modeId) < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMode = modeId
		broadcastQueueUpdates(modeId)
		return
	end

	local players = popPlayers(modeId, mode.maxPlayers)
	cancelFillTimer(modeId)
	pendingMode = nil

	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	for _, queuedPlayer in players do
		if callbacks.onPlayerQueuedForArena then
			callbacks.onPlayerQueuedForArena(queuedPlayer)
		end
	end

	MatchReady:Fire(players, modeId)
end

local function tryLaunchMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMode = modeId
		broadcastQueueUpdates(modeId)
		return
	end

	if mode.waitForFill and #queue < mode.maxPlayers then
		if fillTimers[modeId] then
			return
		end

		fillTimers[modeId] = true
		fillToken[modeId] = (fillToken[modeId] or 0) + 1
		local token = fillToken[modeId]
		broadcastQueueUpdates(modeId)
		task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
			if fillToken[modeId] ~= token then
				return
			end
			fillTimers[modeId] = nil
			launchMatchNow(modeId)
		end)
		return
	end

	launchMatchNow(modeId)
end

local function processPending()
	if not pendingMode then
		for modeId in queues do
			pruneQueue(modeId)
			if #getQueue(modeId) >= (MatchModes.get(modeId).minPlayers or 1) then
				pendingMode = modeId
				break
			end
		end
	end

	if pendingMode then
		local modeId = pendingMode
		task.delay(MatchmakingConfig.ARENA_RETRY_DELAY, function()
			launchMatchNow(modeId)
		end)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if callbacks.getPlayerPhase and callbacks.getPlayerPhase(player) == "arena" then
		return
	end

	MatchmakingService.leaveQueue(player)

	table.insert(getQueue(modeId), player)
	playerMode[player] = modeId
	fireQueueUpdate(player)
	tryLaunchMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	removeFromList(getQueue(modeId), player)

	if fillTimers[modeId] then
		local queue = getQueue(modeId)
		local mode = MatchModes.get(modeId)
		if mode and #queue < mode.minPlayers then
			cancelFillTimer(modeId)
		end
	end

	fireQueueUpdate(player)
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.start(options)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	callbacks = options or {}

	MatchStateService.onArenaFree(processPending)

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

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
