--[[
	MatchmakingService — queue players by mode and launch matches when ready.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local handlers = {}
local queues = {}
local playerQueue = {}
local playerStatus = {}
local fillTimers = {}
local fillEndsAt = {}
local pendingMatch = nil
local initialized = false

for modeId in MatchModes do
	if typeof(MatchModes[modeId]) == "table" and MatchModes[modeId].id then
		queues[modeId] = {}
	end
end

local function cancelFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
	fillEndsAt[modeId] = nil
end

local function removeFromQueue(player, modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
end

local function removeFromAllQueues(player)
	for modeId in queues do
		removeFromQueue(player, modeId)
	end
	playerQueue[player] = nil
	playerStatus[player] = nil
end

local function getQueueCount(modeId)
	return #(queues[modeId] or {})
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local status = playerStatus[player] or "searching"
	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = getQueueCount(modeId),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}

	if fillEndsAt[modeId] then
		payload.fillRemaining = math.max(0, fillEndsAt[modeId] - os.clock())
	end

	return payload
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			sendQueueUpdate(player)
		end
	end
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(taken, player)
		end
	end
	return taken
end

local function setPlayersStatus(players, status)
	for _, player in players do
		playerStatus[player] = status
		sendQueueUpdate(player)
	end
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	cancelFillTimer(modeId)

	for _, player in players do
		removeFromAllQueues(player)
		if handlers.onPlayerEnterArena then
			handlers.onPlayerEnterArena(player)
		end
	end

	Bindables.MatchReady:Fire(players, modeId)
end

local function tryLaunchMatch(modeId, players)
	if #players == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = players,
		}
		setPlayersStatus(players, "pending")
		return
	end

	launchMatch(modeId, players)
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end
	if fillTimers[modeId] then
		return
	end

	fillEndsAt[modeId] = os.clock() + mode.fillTimeout
	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		fillEndsAt[modeId] = nil

		local queue = queues[modeId]
		if queue and #queue >= mode.minPlayers then
			tryLaunchMatch(modeId, takePlayers(modeId, #queue))
		end
		broadcastQueueUpdates()
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue then
		return
	end

	local count = #queue
	if count < mode.minPlayers then
		cancelFillTimer(modeId)
		broadcastQueueUpdates()
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			cancelFillTimer(modeId)
			tryLaunchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
		else
			startFillTimer(modeId)
			setPlayersStatus(queue, "fill")
		end
		return
	end

	if count >= mode.maxPlayers then
		tryLaunchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
	end
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if handlers.getPlayerPhase and handlers.getPlayerPhase(player) == "arena" then
		return
	end
	if MatchStateService.isArenaBusy() and pendingMatch then
		for _, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				return
			end
		end
	end

	removeFromAllQueues(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	playerStatus[player] = "searching"
	sendQueueUpdate(player)

	if handlers.onQueueChanged then
		handlers.onQueueChanged()
	end

	evaluateQueue(modeId)
end

local function leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromAllQueues(player)

	if getQueueCount(modeId) < MatchModes.get(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	sendQueueUpdate(player)

	if handlers.onQueueChanged then
		handlers.onQueueChanged()
	end

	evaluateQueue(modeId)
end

local function onMatchEnded()
	MatchStateService.setArenaBusy(false)

	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		tryLaunchMatch(match.modeId, match.players)
		return
	end

	for modeId in queues do
		evaluateQueue(modeId)
	end
end

local function onPlayerRemoving(player)
	removeFromAllQueues(player)

	if pendingMatch then
		local filtered = {}
		for _, pendingPlayer in pendingMatch.players do
			if pendingPlayer ~= player and pendingPlayer.Parent then
				table.insert(filtered, pendingPlayer)
			end
		end
		if #filtered == 0 then
			pendingMatch = nil
		else
			pendingMatch.players = filtered
		end
	end
end

function MatchmakingService.init(newHandlers)
	if initialized then
		return
	end
	initialized = true
	handlers = newHandlers or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(onMatchEnded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastQueueUpdates()
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

return MatchmakingService
