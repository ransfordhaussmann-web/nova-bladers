local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local fillTokens = {}
local pendingStarts = {}
local initialized = false

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
end

local function queueCount(modeId)
	return #getQueue(modeId)
end

local function buildUpdatePayload(modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local names = {}
	for _, queuedPlayer in getQueue(modeId) do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		status = status or "waiting",
		players = names,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function fireQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdate(modeId, status)
	local payload = buildUpdatePayload(modeId, status)
	if not payload then
		return
	end

	for _, queuedPlayer in getQueue(modeId) do
		fireQueueUpdate(queuedPlayer, payload)
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillTimers[modeId] = nil
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout and fillTimers[modeId] then
		return true
	end
	if not mode.fillTimeout and count >= mode.minPlayers then
		return true
	end
	return false
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local ready = {}

	for i = 1, math.min(#queue, mode.maxPlayers) do
		local queuedPlayer = queue[i]
		if queuedPlayer.Parent and playerQueue[queuedPlayer] then
			table.insert(ready, queuedPlayer)
		end
	end

	return ready
end

local function startMatch(modeId, readyPlayers)
	clearFillTimer(modeId)

	for _, queuedPlayer in readyPlayers do
		removeFromQueue(queuedPlayer)
	end

	MatchStateService.setMatchActive(true)
	MatchReady:Fire(readyPlayers, modeId)

	for _, queuedPlayer in readyPlayers do
		fireQueueUpdate(queuedPlayer, {
			modeId = modeId,
			status = "starting",
			count = #readyPlayers,
		})
	end

	broadcastQueueUpdate(modeId, "waiting")
end

local function tryStartMatch(modeId)
	if not canStartMatch(modeId) then
		return
	end

	local readyPlayers = collectReadyPlayers(modeId)
	if #readyPlayers == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingStarts[modeId] = true
		broadcastQueueUpdate(modeId, "pending")
		return
	end

	pendingStarts[modeId] = false
	task.delay(MatchmakingConfig.START_DELAY, function()
		startMatch(modeId, readyPlayers)
	end)
end

local function maybeStartFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if queueCount(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	fillTimers[modeId] = true

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player].modeId == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	if queueCount(modeId) >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }

	broadcastQueueUpdate(modeId, MatchStateService.isArenaBusy() and "pending" or "waiting")
	fireQueueUpdate(player, buildUpdatePayload(modeId, "waiting"))

	if queueCount(modeId) >= mode.maxPlayers then
		tryStartMatch(modeId)
	else
		maybeStartFillTimer(modeId)
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	removeFromQueue(player)

	if queueCount(modeId) < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
		pendingStarts[modeId] = false
	end

	broadcastQueueUpdate(modeId, "waiting")
	fireQueueUpdate(player, { status = "idle" })
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

local function processPendingStarts()
	for modeId, pending in pendingStarts do
		if pending and canStartMatch(modeId) and not MatchStateService.isArenaBusy() then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
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
		task.defer(processPendingStarts)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
			if MatchStateService.isArenaBusy() then
				continue
			end
			processPendingStarts()
		end
	end)
end

return MatchmakingService
