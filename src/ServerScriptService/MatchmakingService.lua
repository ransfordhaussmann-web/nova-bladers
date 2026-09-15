local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingLaunches = {}
local pendingPlayers = {}
local hubApi = nil
local started = false

local function initQueues()
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {
			mode = mode,
			players = {},
		}
	end
end

local function getQueueCount(modeId)
	return #queues[modeId].players
end

local function buildPayload(modeId, player, status)
	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
	}
end

local function sendQueueClear(player)
	if player.Parent then
		QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function broadcastQueue(modeId, status)
	local payload = buildPayload(modeId, nil, status)
	for _, player in queues[modeId].players do
		if player.Parent then
			QueueUpdate:FireClient(player, payload)
		end
	end
end

local function cancelFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end
	playerQueue[player] = nil
	sendQueueClear(player)

	local mode = queue.mode
	if mode.fillTimeout and getQueueCount(modeId) < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function leaveHubForMatch(players)
	if hubApi and hubApi.leaveHubForArena then
		for _, player in players do
			hubApi.leaveHubForArena(player)
		end
	end
end

local function notifyPending(players, modeId)
	for _, player in players do
		if player.Parent then
			QueueUpdate:FireClient(player, buildPayload(modeId, player, "pending"))
		end
	end
end

local function clearPendingPlayers(players)
	for _, player in players do
		pendingPlayers[player] = nil
	end
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	if MatchStateService.isBusy() then
		for _, player in players do
			pendingPlayers[player] = modeId
		end
		table.insert(pendingLaunches, {
			modeId = modeId,
			players = players,
		})
		notifyPending(players, modeId)
		return
	end

	cancelFillTimer(modeId)
	clearPendingPlayers(players)
	leaveHubForMatch(players)
	MatchReady:Fire(players)
end

local function tryLaunch(modeId)
	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)

	if count >= mode.maxPlayers then
		launchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
		return
	end

	if mode.id == "training" and count >= 1 then
		launchMatch(modeId, takePlayers(modeId, 1))
		return
	end

	if mode.id == "pvp" and count >= 2 then
		launchMatch(modeId, takePlayers(modeId, 2))
		return
	end

	if mode.id == "ffa" and count >= mode.minPlayers then
		if not fillTimers[modeId] then
			local token = {}
			fillTimers[modeId] = token
			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if fillTimers[modeId] ~= token then
					return
				end
				fillTimers[modeId] = nil
				local readyCount = getQueueCount(modeId)
				if readyCount >= mode.minPlayers then
					launchMatch(modeId, takePlayers(modeId, math.min(readyCount, mode.maxPlayers)))
				end
			end)
		end
	end
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if hubApi and hubApi.getPhase and hubApi.getPhase(player) ~= "hub" then
		return
	end

	if playerQueue[player] then
		removePlayerFromQueue(player)
	end

	local queue = queues[modeId]
	if #queue.players >= mode.maxPlayers then
		return
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId
	QueueUpdate:FireClient(player, buildPayload(modeId, player, MatchStateService.isBusy() and "pending" or "waiting"))
	broadcastQueue(modeId, MatchStateService.isBusy() and "pending" or "waiting")
	tryLaunch(modeId)
end

local function processPendingLaunches()
	if MatchStateService.isBusy() or #pendingLaunches == 0 then
		return
	end

	local nextLaunch = table.remove(pendingLaunches, 1)
	if not nextLaunch then
		return
	end

	local activePlayers = {}
	for _, player in nextLaunch.players do
		if player.Parent then
			table.insert(activePlayers, player)
		else
			pendingPlayers[player] = nil
		end
	end

	if #activePlayers == 0 then
		processPendingLaunches()
		return
	end

	clearPendingPlayers(activePlayers)
	leaveHubForMatch(activePlayers)
	MatchReady:Fire(activePlayers)
end

function MatchmakingService.start(api)
	if started then
		return
	end
	started = true
	hubApi = api
	initQueues()

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		removePlayerFromQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromQueue(player)
		pendingPlayers[player] = nil
		for index, launch in pendingLaunches do
			for playerIndex, queuedPlayer in launch.players do
				if queuedPlayer == player then
					table.remove(launch.players, playerIndex)
					break
				end
			end
			if #launch.players == 0 then
				table.remove(pendingLaunches, index)
			end
		end
	end)

	MatchStateService.onArenaFreed(function()
		task.delay(MatchmakingConfig.ARENA_BUSY_RETRY, processPendingLaunches)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

return MatchmakingService
