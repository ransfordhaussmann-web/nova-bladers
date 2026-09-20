local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady
local MatchEnded

local queues = {}
local playerQueue = {}
local fillTimers = {}
local fillDeadline = {}
local initialized = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getPlayerName(player)
	return player.DisplayName or player.Name
end

local function buildQueueNames(modeId)
	local names = {}
	for _, queuedPlayer in getQueue(modeId) do
		if queuedPlayer.Parent then
			table.insert(names, getPlayerName(queuedPlayer))
		end
	end
	return names
end

local function getFillRemaining(modeId)
	local deadline = fillDeadline[modeId]
	if not deadline then
		return nil
	end
	return math.max(0, math.ceil(deadline - os.clock()))
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local pending = MatchStateService.isArenaBusy()
	local ready = count >= mode.minPlayers and not pending

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = buildQueueNames(modeId),
		playerCount = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		ready = ready,
		fillTimeoutRemaining = mode.fillTimeout and getFillRemaining(modeId),
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(nil, modeId)
	for _, queuedPlayer in getQueue(modeId) do
		sendQueueUpdate(queuedPlayer, payload)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
	fillDeadline[modeId] = nil
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerQueue[player] = nil

	local mode = MatchModes.get(modeId)
	if #queue < mode.minPlayers then
		clearFillTimer(modeId)
	end

	if not silent then
		sendQueueUpdate(player, { inQueue = false })
		broadcastQueueUpdate(modeId)
	end
end

local function popQueuePlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function notifyMatchReady(players, modeId)
	for _, player in players do
		sendQueueUpdate(player, { inQueue = false })
	end
	MatchReady:Fire(players, modeId)
end

local function startQueuedMatch(modeId)
	clearFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	local players = popQueuePlayers(modeId, mode.maxPlayers)
	if #players >= mode.minPlayers then
		notifyMatchReady(players, modeId)
	end
end

local function tryStartMatch(modeId, forceStart)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if mode.maxPlayers and #queue >= mode.maxPlayers then
		startQueuedMatch(modeId)
		return
	end

	if mode.fillTimeout and not forceStart then
		if not fillTimers[modeId] then
			fillDeadline[modeId] = os.clock() + mode.fillTimeout
			fillTimers[modeId] = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				fillDeadline[modeId] = nil
				tryStartMatch(modeId, true)
			end)
		end
		broadcastQueueUpdate(modeId)
		return
	end

	startQueuedMatch(modeId)
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		broadcastQueueUpdate(modeId)
		return true
	end

	removeFromQueue(player, true)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	sendQueueUpdate(player, buildQueuePayload(player, modeId))
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)

	return true
end

local function leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player, { inQueue = false })
		return
	end
	removeFromQueue(player, false)
end

local function onMatchEnded()
	task.defer(function()
		for modeId, _ in queues do
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.init(remotes, bindables)
	if initialized then
		return
	end
	initialized = true

	Remotes = remotes
	MatchReady = bindables.MatchReady
	MatchEnded = bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	MatchEnded.Event:Connect(onMatchEnded)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId, queue in queues do
				if queue and #queue > 0 then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	return joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

return MatchmakingService
