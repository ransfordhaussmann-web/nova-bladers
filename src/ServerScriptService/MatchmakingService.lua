local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerMode = {}
local fillTimers = {}
local pendingMatch = nil
local started = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

local function isPlayerValid(player)
	return player and player.Parent == Players
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerMode[player] = nil
end

local function addToQueue(player, modeId)
	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
end

local function buildQueuePayload(player, status)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = #queue
	local needed = math.max(0, mode.minPlayers - count)

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = mode.label,
		count = count,
		needed = needed,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
	}
end

local function sendQueueUpdate(player, status)
	if not isPlayerValid(player) then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, status))
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	for _, player in queue do
		sendQueueUpdate(player, "waiting")
	end
end

local function cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function takePlayers(modeId, amount)
	local queue = queues[modeId]
	local taken = {}
	local limit = math.min(amount, #queue)

	for _ = 1, limit do
		local player = table.remove(queue, 1)
		if player then
			playerMode[player] = nil
			if isPlayerValid(player) then
				table.insert(taken, player)
			end
		end
	end

	return taken
end

local function markPlayersPending(players)
	for _, player in players do
		sendQueueUpdate(player, "pending")
	end
end

local function markPlayersStarting(players)
	for _, player in players do
		sendQueueUpdate(player, "starting")
	end
end

local function leaveArenaForPlayers(players, leaveHub)
	for _, player in players do
		if isPlayerValid(player) then
			leaveHub(player)
		end
	end
end

local function launchMatch(players, modeId, leaveHub)
	if #players == 0 then
		return
	end

	markPlayersStarting(players)
	leaveArenaForPlayers(players, leaveHub)
	Bindables.MatchReady:Fire(players, modeId)
end

local function tryStartPending()
	if not pendingMatch or not GameMatchState.isFree() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	launchMatch(match.players, match.modeId, match.leaveHub)
end

local function queueMatch(players, modeId, leaveHub)
	if GameMatchState.isFree() then
		launchMatch(players, modeId, leaveHub)
		return
	end

	pendingMatch = {
		players = players,
		modeId = modeId,
		leaveHub = leaveHub,
	}
	markPlayersPending(players)
end

local function tryStartMode(modeId, leaveHub)
	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" and #queue < mode.maxPlayers and fillTimers[modeId] then
		return
	end

	cancelFillTimer(modeId)
	local amount = math.min(#queue, mode.maxPlayers)
	local players = takePlayers(modeId, amount)
	queueMatch(players, modeId, leaveHub)
	broadcastQueue(modeId)
end

local function scheduleFillTimer(modeId, leaveHub)
	if fillTimers[modeId] then
		return
	end

	local mode = getModeConfig(modeId)
	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMode(modeId, leaveHub)
	end)
end

local function onQueueChanged(modeId, leaveHub)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]

	if modeId == "ffa" then
		if #queue < mode.minPlayers then
			cancelFillTimer(modeId)
		elseif #queue >= mode.maxPlayers then
			tryStartMode(modeId, leaveHub)
		elseif #queue >= mode.minPlayers then
			scheduleFillTimer(modeId, leaveHub)
		end
		return
	end

	if #queue >= mode.minPlayers then
		tryStartMode(modeId, leaveHub)
	end
end

function MatchmakingService.joinQueue(player, modeId, leaveHub)
	if not isPlayerValid(player) then
		return
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	addToQueue(player, modeId)
	sendQueueUpdate(player, "waiting")
	broadcastQueue(modeId)
	onQueueChanged(modeId, leaveHub)
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		sendQueueUpdate(player, nil)
		return
	end

	local modeId = playerMode[player]
	removeFromQueue(player)
	sendQueueUpdate(player, nil)
	broadcastQueue(modeId)

	local mode = getModeConfig(modeId)
	if modeId == "ffa" and queues[modeId] and #queues[modeId] < mode.minPlayers then
		cancelFillTimer(modeId)
	end
end

function MatchmakingService.start(options)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	local leaveHub = options.leaveHub

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId, leaveHub)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		tryStartPending()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)

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
	end)
end

return MatchmakingService
