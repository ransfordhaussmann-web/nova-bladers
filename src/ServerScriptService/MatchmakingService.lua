local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingStarts = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getModeConfig(modeId)
	return MatchmakingConfig.get(modeId)
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return nil
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	return entry.modeId
end

local function removePendingPlayer(player)
	for modeId, pending in pendingStarts do
		if pending and pending.players then
			for i, pendingPlayer in pending.players do
				if pendingPlayer == player then
					table.remove(pending.players, i)
					if #pending.players == 0 then
						pendingStarts[modeId] = nil
					end
					return modeId
				end
			end
		end
	end
	return nil
end

local function buildQueuePayload(player, modeId, status)
	local config = getModeConfig(modeId)
	if not config then
		return { inQueue = false }
	end

	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local payload = {
		inQueue = true,
		mode = modeId,
		modeLabel = config.label,
		position = position,
		queued = #queue,
		needed = config.minPlayers,
		max = config.maxPlayers,
		status = status or "waiting",
	}

	local timer = fillTimers[modeId]
	if timer and timer.endsAt then
		payload.fillTimeLeft = math.max(0, math.ceil(timer.endsAt - os.clock()))
	end

	return payload
end

local function sendQueueUpdate(player, modeId, status)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
	end
end

local function clearQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function broadcastQueue(modeId, status)
	local queue = getQueue(modeId)
	for _, player in queue do
		sendQueueUpdate(player, modeId, status)
	end
end

local function cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer and timer.thread then
		task.cancel(timer.thread)
	end
	fillTimers[modeId] = nil
end

local function canStartMode(modeId)
	local config = getModeConfig(modeId)
	local queue = getQueue(modeId)
	if not config or #queue < config.minPlayers then
		return false
	end

	if config.fillTimeout > 0 then
		local timer = fillTimers[modeId]
		if timer and timer.endsAt and os.clock() < timer.endsAt and #queue < config.maxPlayers then
			return false
		end
	end

	return true
end

local function takePlayersForMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, config.maxPlayers)
	local matchPlayers = {}

	for i = 1, count do
		local player = queue[1]
		table.remove(queue, 1)
		table.insert(matchPlayers, player)
	end

	cancelFillTimer(modeId)
	return matchPlayers
end

local function startMatch(modeId, matchPlayers)
	for _, player in matchPlayers do
		playerQueue[player] = nil
		clearQueueUpdate(player)
		HubService.leaveHubForArena(player)
	end

	MatchReady:Fire({
		mode = modeId,
		players = matchPlayers,
	})
end

local function tryStartMode(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	while canStartMode(modeId) do
		local matchPlayers = takePlayersForMatch(modeId)
		if #matchPlayers == 0 then
			return
		end

		for _, player in matchPlayers do
			playerQueue[player] = { modeId = modeId, pending = false }
		end

		if MatchStateService.isBusy() then
			pendingStarts[modeId] = {
				mode = modeId,
				players = matchPlayers,
			}
			for _, player in matchPlayers do
				playerQueue[player] = { modeId = modeId, pending = true }
				sendQueueUpdate(player, modeId, "pending")
			end
			return
		end

		startMatch(modeId, matchPlayers)
	end
end

local function maybeStartFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config or config.fillTimeout <= 0 then
		return
	end

	local queue = getQueue(modeId)
	if #queue < config.minPlayers then
		cancelFillTimer(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	local endsAt = os.clock() + config.fillTimeout
	fillTimers[modeId] = {
		endsAt = endsAt,
		thread = task.delay(config.fillTimeout, function()
			fillTimers[modeId] = nil
			broadcastQueue(modeId, "waiting")
			tryStartMode(modeId)
		end),
	}
end

local function evaluateMode(modeId)
	maybeStartFillTimer(modeId)
	tryStartMode(modeId)
	broadcastQueue(modeId, MatchStateService.isBusy() and "pending" or "waiting")
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	MatchmakingService.leaveQueue(player)
	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }

	evaluateMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	local modeId
	if entry then
		modeId = entry.modeId
		if entry.pending then
			removePendingPlayer(player)
			playerQueue[player] = nil
		else
			modeId = removeFromQueue(player)
		end
	else
		modeId = removePendingPlayer(player)
	end

	if not modeId then
		return
	end

	clearQueueUpdate(player)

	local config = getModeConfig(modeId)
	if config and config.fillTimeout > 0 then
		local queue = getQueue(modeId)
		if #queue < config.minPlayers then
			cancelFillTimer(modeId)
		end
	end

	broadcastQueue(modeId, "waiting")
end

function MatchmakingService.onMatchEnded()
	for modeId, pending in pendingStarts do
		if pending and pending.players and #pending.players > 0 then
			local readyPlayers = {}
			for _, player in pending.players do
				if player.Parent and playerQueue[player] and HubService.getPhase(player) == "hub" then
					table.insert(readyPlayers, player)
				else
					playerQueue[player] = nil
					clearQueueUpdate(player)
				end
			end

			pendingStarts[modeId] = nil
			if #readyPlayers > 0 and not MatchStateService.isBusy() then
				startMatch(modeId, readyPlayers)
				return
			end
		end
	end

	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

function MatchmakingService.init(remotes, bindables)
	Remotes = remotes
	MatchReady = bindables.MatchReady

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
		local entry = playerQueue[player]
		local modeId = entry and entry.modeId or removePendingPlayer(player)
		if not modeId then
			return
		end

		removeFromQueue(player)
		removePendingPlayer(player)

		local config = getModeConfig(modeId)
		if config and config.fillTimeout > 0 then
			local queue = getQueue(modeId)
			if #queue < config.minPlayers then
				cancelFillTimer(modeId)
			end
		end

		broadcastQueue(modeId, "waiting")
	end)
end

return MatchmakingService
