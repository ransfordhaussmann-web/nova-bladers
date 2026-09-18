--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local remotes
local matchReadyBindable
local getPhase

local function getQueue(modeId)
	return queues[modeId]
end

local function playerName(player)
	return player.DisplayName or player.Name
end

local function isValidHubPlayer(player)
	return player.Parent and getPhase(player) == "hub"
end

local function buildQueueNames(modeId)
	local names = {}
	for _, queuedPlayer in ipairs(getQueue(modeId)) do
		if queuedPlayer.Parent then
			table.insert(names, playerName(queuedPlayer))
		end
	end
	return names
end

local function buildUpdatePayload(modeId, player, status)
	local mode = MatchModes.get(modeId)
	local count = #getQueue(modeId)
	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = buildQueueNames(modeId),
		count = count,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
	}

	if modeId == "ffa" and fillTimers[modeId] then
		payload.fillTimeout = fillTimers[modeId].remaining
	end

	return payload
end

local function sendQueueUpdate(player, modeId, status)
	if not remotes or not player.Parent then
		return
	end
	remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player, status))
end

local function broadcastQueueUpdate(modeId, status)
	for _, queuedPlayer in ipairs(getQueue(modeId)) do
		sendQueueUpdate(queuedPlayer, modeId, status)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for index, queuedPlayer in ipairs(queue) do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil

	if modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		clearFillTimer(modeId)
	end

	if remotes and player.Parent then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	broadcastQueueUpdate(modeId, MatchStateService.isArenaBusy() and "pending" or "waiting")
end

local function queueHasPlayer(modeId, player)
	for _, queuedPlayer in ipairs(getQueue(modeId)) do
		if queuedPlayer == player then
			return true
		end
	end
	return false
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local cleaned = {}
	for _, queuedPlayer in ipairs(queue) do
		if isValidHubPlayer(queuedPlayer) then
			table.insert(cleaned, queuedPlayer)
		else
			playerMode[queuedPlayer] = nil
		end
	end
	queues[modeId] = cleaned
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	pruneQueue(modeId)
	local count = #getQueue(modeId)
	return count >= mode.minPlayers
end

local function shouldStartImmediately(modeId)
	local mode = MatchModes.get(modeId)
	pruneQueue(modeId)
	local count = #getQueue(modeId)
	return count >= mode.maxPlayers
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local timerState = {
		cancelled = false,
		remaining = MatchmakingConfig.FFA_FILL_TIMEOUT,
	}
	fillTimers[modeId] = timerState

	task.spawn(function()
		while fillTimers[modeId] == timerState and not timerState.cancelled do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			if fillTimers[modeId] ~= timerState or timerState.cancelled then
				return
			end

			timerState.remaining = math.max(0, timerState.remaining - MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			broadcastQueueUpdate(modeId, MatchStateService.isArenaBusy() and "pending" or "waiting")

			if timerState.remaining <= 0 then
				clearFillTimer(modeId)
				MatchmakingService.tryStartMatch(modeId)
				return
			end
		end
	end)
end

local function popReadyPlayers(modeId)
	pruneQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local ready = {}

	for index = 1, count do
		local queuedPlayer = queue[index]
		table.insert(ready, queuedPlayer)
	end

	queues[modeId] = {}
	clearFillTimer(modeId)

	for _, queuedPlayer in ipairs(ready) do
		playerMode[queuedPlayer] = nil
		if remotes and queuedPlayer.Parent then
			remotes.QueueUpdate:FireClient(queuedPlayer, { inQueue = false })
		end
	end

	return ready
end

function MatchmakingService.tryStartMatch(modeId)
	if not canStartMode(modeId) then
		return false
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId, "pending")
		return false
	end

	local readyPlayers = popReadyPlayers(modeId)
	if #readyPlayers == 0 then
		return false
	end

	if not MatchStateService.tryReserveArena() then
		for _, queuedPlayer in readyPlayers do
			table.insert(getQueue(modeId), queuedPlayer)
			playerMode[queuedPlayer] = modeId
		end
		broadcastQueueUpdate(modeId, "pending")
		return false
	end

	broadcastQueueUpdate(modeId, "starting")

	matchReadyBindable:Fire({
		players = readyPlayers,
		modeId = modeId,
	})

	return true
end

local function evaluateMode(modeId)
	if shouldStartImmediately(modeId) then
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if modeId == "ffa" and canStartMode(modeId) then
		if not fillTimers[modeId] then
			startFillTimer(modeId)
		end
		broadcastQueueUpdate(modeId, MatchStateService.isArenaBusy() and "pending" or "waiting")
		return
	end

	if canStartMode(modeId) then
		MatchmakingService.tryStartMatch(modeId)
	else
		broadcastQueueUpdate(modeId, MatchStateService.isArenaBusy() and "pending" or "waiting")
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end
	if not isValidHubPlayer(player) then
		return
	end

	if playerMode[player] == modeId and queueHasPlayer(modeId, player) then
		sendQueueUpdate(player, modeId, MatchStateService.isArenaBusy() and "pending" or "waiting")
		return
	end

	MatchmakingService.leaveQueue(player)

	table.insert(getQueue(modeId), player)
	playerMode[player] = modeId

	sendQueueUpdate(player, modeId, MatchStateService.isArenaBusy() and "pending" or "waiting")
	broadcastQueueUpdate(modeId, MatchStateService.isArenaBusy() and "pending" or "waiting")
	evaluateMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.init(options)
	remotes = options.remotes
	matchReadyBindable = options.matchReadyBindable
	getPhase = options.getPhase

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.getRecommended(#Players:GetPlayers()).id
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		for modeId in pairs(queues) do
			if #getQueue(modeId) > 0 then
				evaluateMode(modeId)
			end
		end
	end)
end

return MatchmakingService
