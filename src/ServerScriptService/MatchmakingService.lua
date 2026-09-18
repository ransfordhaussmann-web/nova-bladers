local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingModes = {}
local hubCallbacks = {}

local function initQueues()
	for _, modeId in MatchModes.all() do
		queues[modeId] = {}
	end
end

local function removeFromQueueList(modeId, player)
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = queues[entry.modeId]
	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = entry.status,
		fillTimeout = entry.fillTimeout,
	}
end

local function broadcastQueue(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllQueues()
	for player, _ in playerQueue do
		if player.Parent then
			broadcastQueue(player)
		end
	end
end

local function setPlayerStatus(player, status, fillTimeout)
	local entry = playerQueue[player]
	if entry then
		entry.status = status
		entry.fillTimeout = fillTimeout
	end
end

local function markModePending(modeId)
	if not pendingModes[modeId] then
		pendingModes[modeId] = true
	end
	for _, queuedPlayer in queues[modeId] do
		if playerQueue[queuedPlayer] then
			setPlayerStatus(queuedPlayer, "pending")
			broadcastQueue(queuedPlayer)
		end
	end
end

local function clearModePending(modeId)
	pendingModes[modeId] = nil
	for _, queuedPlayer in queues[modeId] do
		if playerQueue[queuedPlayer] then
			setPlayerStatus(queuedPlayer, "waiting")
			broadcastQueue(queuedPlayer)
		end
	end
end

local function leaveHubForQueuedPlayers(players)
	for _, player in players do
		if hubCallbacks.leaveHubForArena then
			hubCallbacks.leaveHubForArena(player)
		end
	end
end

local function popPlayersFromQueue(modeId, count)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local players = {}
	local take = math.min(count, #queue, mode.maxPlayers)

	for _ = 1, take do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(players, player)
			playerQueue[player] = nil
		end
	end

	return players
end

local function startMatch(modeId, playerCount)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local players = popPlayersFromQueue(modeId, playerCount or mode.maxPlayers)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerQueue[player] = {
				modeId = modeId,
				status = "waiting",
			}
		end
		return
	end

	clearFillTimer(modeId)
	clearModePending(modeId)
	leaveHubForQueuedPlayers(players)

	for _, player in players do
		setPlayerStatus(player, "starting")
		broadcastQueue(player)
	end

	MatchStateService.setBusy(true)
	Bindables.MatchReady:Fire(players, modeId)
	broadcastAllQueues()

	if hubCallbacks.broadcastLobbyUpdate then
		hubCallbacks.broadcastLobbyUpdate()
	end
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		markModePending(modeId)
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			startMatch(modeId, mode.maxPlayers)
			return
		end

		if fillTimers[modeId] then
			return
		end

		local deadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
		for _, queuedPlayer in queue do
			playerQueue[queuedPlayer].fillTimeout = MatchmakingConfig.FFA_FILL_TIMEOUT
			setPlayerStatus(queuedPlayer, "waiting")
			broadcastQueue(queuedPlayer)
		end

		fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
			fillTimers[modeId] = nil
			if #queues[modeId] < mode.minPlayers then
				return
			end
			if MatchStateService.isBusy() then
				markModePending(modeId)
				return
			end
			startMatch(modeId, #queues[modeId])
		end)

		task.spawn(function()
			while fillTimers[modeId] do
				local remaining = math.max(0, math.ceil(deadline - os.clock()))
				for _, queuedPlayer in queues[modeId] do
					local entry = playerQueue[queuedPlayer]
					if entry then
						entry.fillTimeout = remaining
						broadcastQueue(queuedPlayer)
					end
				end
				if remaining <= 0 then
					break
				end
				task.wait(1)
			end
		end)
		return
	end

	startMatch(modeId, mode.minPlayers)
end

local function processPendingQueues()
	for _, modeId in MatchModes.all() do
		if pendingModes[modeId] and not MatchStateService.isBusy() then
			local mode = MatchModes.get(modeId)
			if #queues[modeId] >= mode.minPlayers then
				if modeId == "ffa" and fillTimers[modeId] then
					-- FFA timer still running; wait for timeout or max players.
				elseif modeId == "ffa" then
					tryStartMatch(modeId)
				else
					startMatch(modeId, mode.minPlayers)
				end
			else
				clearModePending(modeId)
			end
		end
	end
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		broadcastQueue(player)
		return
	end

	local modeId = entry.modeId
	removeFromQueueList(modeId, player)
	playerQueue[player] = nil

	if #queues[modeId] == 0 then
		clearFillTimer(modeId)
		clearModePending(modeId)
	end

	broadcastQueue(player)
	broadcastAllQueues()

	if hubCallbacks.broadcastLobbyUpdate then
		hubCallbacks.broadcastLobbyUpdate()
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if hubCallbacks.getPhase and hubCallbacks.getPhase(player) == "arena" then
		return
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = {
		modeId = modeId,
		status = "waiting",
	}

	broadcastQueue(player)
	broadcastAllQueues()

	if hubCallbacks.broadcastLobbyUpdate then
		hubCallbacks.broadcastLobbyUpdate()
	end

	tryStartMatch(modeId)
end

function MatchmakingService.getQueueSize(modeId)
	return #(queues[modeId] or {})
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.init(callbacks)
	hubCallbacks = callbacks or {}
	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

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

	MatchStateService.onArenaFreed(function()
		processPendingQueues()
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
