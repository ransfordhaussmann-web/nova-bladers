local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local Bindables
local MatchReadyBindable

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil
local onEnterArena = nil

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player, modeId, status, fillSecondsLeft)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = getQueueCount(modeId),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "searching",
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates(modeId, status, fillSecondsLeft)
	local payload = buildQueuePayload(nil, modeId, status, fillSecondsLeft)
	payload.inQueue = true
	payload.players = getQueueCount(modeId)

	for _, queuedPlayer in queues[modeId] do
		sendQueueUpdate(queuedPlayer, payload)
	end
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if not silent then
		sendQueueUpdate(player, { inQueue = false })
	end

	if getQueueCount(modeId) < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdates(modeId, "searching")
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	clearFillTimer(modeId)
	return taken
end

local function launchMatch(modeId, playerList)
	pendingMatch = nil
	broadcastQueueUpdates(modeId, "starting")

	for _, player in playerList do
		sendQueueUpdate(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = MatchModes.get(modeId).label,
			players = #playerList,
			minPlayers = #playerList,
			maxPlayers = #playerList,
			status = "starting",
		})
		if onEnterArena then
			onEnterArena(player)
		end
	end

	MatchReadyBindable:Fire(playerList, modeId)
end

local function tryLaunchMode(modeId)
	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)

	if count == 0 then
		return
	end

	if MatchStateService.isBusy() then
		if not pendingMatch or pendingMatch.modeId ~= modeId then
			pendingMatch = { modeId = modeId }
		end
		broadcastQueueUpdates(modeId, "pending")
		return
	end

	if count >= mode.maxPlayers then
		local players = takePlayersFromQueue(modeId, mode.maxPlayers)
		if #players > 0 then
			launchMatch(modeId, players)
		end
		return
	end

	if mode.id == "training" and count >= 1 then
		local players = takePlayersFromQueue(modeId, 1)
		if #players > 0 then
			launchMatch(modeId, players)
		end
		return
	end

	if mode.id == "pvp" and count >= 2 then
		local players = takePlayersFromQueue(modeId, 2)
		if #players >= 2 then
			launchMatch(modeId, players)
		end
		return
	end

	if count >= mode.minPlayers and mode.fillTimeout and not fillTimers[modeId] then
		local deadline = os.clock() + mode.fillTimeout
		fillTimers[modeId] = task.spawn(function()
			while fillTimers[modeId] do
				local remaining = math.max(0, math.ceil(deadline - os.clock()))
				broadcastQueueUpdates(modeId, "searching", remaining)
				if os.clock() >= deadline then
					break
				end
				task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			end

			fillTimers[modeId] = nil

			if MatchStateService.isBusy() then
				pendingMatch = { modeId = modeId }
				broadcastQueueUpdates(modeId, "pending")
				return
			end

			local readyCount = getQueueCount(modeId)
			if readyCount >= mode.minPlayers then
				local players = takePlayersFromQueue(modeId, math.min(readyCount, mode.maxPlayers))
				if #players >= mode.minPlayers then
					launchMatch(modeId, players)
				end
			end
		end)
	end
end

local function tryLaunchPending()
	if not pendingMatch or MatchStateService.isBusy() then
		return
	end

	local modeId = pendingMatch.modeId
	pendingMatch = nil

	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	local players = takePlayersFromQueue(modeId, math.min(count, mode.maxPlayers))
	if #players >= mode.minPlayers then
		launchMatch(modeId, players)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		return
	end

	removeFromQueue(player, true)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	sendQueueUpdate(player, buildQueuePayload(player, modeId, "searching"))
	broadcastQueueUpdates(modeId, "searching")
	tryLaunchMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player, false)
end

function MatchmakingService.getPreferredModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.init(options)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReadyBindable = Bindables.MatchReady
	onEnterArena = options and options.onEnterArena

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getPreferredModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	MatchStateService.onArenaIdle(function()
		tryLaunchPending()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
			if pendingMatch and not MatchStateService.isBusy() then
				tryLaunchPending()
			end
		end
	end)
end

return MatchmakingService
