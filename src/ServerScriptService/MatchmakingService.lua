local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local readySince = {}
local fillTimers = {}

local handlers = {}

local function getMode(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function buildQueueUpdate(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = queues[modeId] or {}
	local count = #queue
	local needed = mode.minPlayers
	local status = "waiting"
	local message = string.format("Warteschlange: %d/%d", count, needed)

	if MatchStateService.isArenaBusy() then
		status = "pending"
		message = "Arena belegt — du bist in der Warteschlange"
	elseif count >= needed then
		if modeId == "ffa" and fillTimers[modeId] then
			local remaining = math.max(0, math.ceil(fillTimers[modeId] - os.clock()))
			if remaining > 0 and count < mode.maxPlayers then
				status = "filling"
				message = string.format("FFA startet in %ds (%d/%d)", remaining, count, mode.maxPlayers)
			else
				status = "starting"
				message = "Match startet gleich..."
			end
		else
			status = "starting"
			message = "Match startet gleich..."
		end
	elseif modeId == "pvp" and count == 1 then
		message = "Warte auf Gegner..."
	elseif modeId == "ffa" and count < needed then
		message = string.format("Warte auf Spieler (%d/%d)", count, needed)
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		playersNeeded = needed,
		maxPlayers = mode.maxPlayers,
		status = status,
		message = message,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
		return
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueueUpdate(player, modeId))
	end
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, player in queue do
		sendQueueUpdate(player)
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function maybeStartFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	local queue = queues[modeId]
	if not queue or #queue < mode.minPlayers then
		clearFillTimer(modeId)
		return
	end

	if not fillTimers[modeId] then
		fillTimers[modeId] = os.clock() + mode.fillTimeout
	end
end

local function removeFromQueue(player, modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if #queue == 0 then
		readySince[modeId] = nil
		clearFillTimer(modeId)
	end

	if playerQueue[player] == modeId then
		playerQueue[player] = nil
	end
end

local function takeReadyPlayers(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not mode or not queue or #queue < mode.minPlayers then
		return nil
	end

	if mode.fillTimeout and fillTimers[modeId] then
		local filled = #queue >= mode.maxPlayers
		local timedOut = os.clock() >= fillTimers[modeId]
		if not filled and not timedOut then
			return nil
		end
	end

	local batch = {}
	for index = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(batch, queue[index])
	end

	for _, player in batch do
		removeFromQueue(player, modeId)
		playerQueue[player] = nil
	end

	readySince[modeId] = nil
	clearFillTimer(modeId)
	broadcastQueue(modeId)

	return batch
end

local function leaveHubForMatch(player)
	if handlers.leaveHubForArena then
		handlers.leaveHubForArena(player)
	end
end

local function startBatch(modeId, batch)
	MatchStateService.setArenaBusy(true)

	for _, player in batch do
		leaveHubForMatch(player)
		sendQueueUpdate(player)
	end

	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = batch,
	})
end

function MatchmakingService.tryStartMatch()
	if MatchStateService.isArenaBusy() then
		return
	end

	local bestModeId
	local bestReadySince = math.huge

	for _, modeId in MatchmakingConfig.MODE_ORDER do
		local mode = getMode(modeId)
		local queue = queues[modeId]
		if mode and queue and #queue >= mode.minPlayers then
			if mode.fillTimeout then
				maybeStartFillTimer(modeId)
				local filled = #queue >= mode.maxPlayers
				local timedOut = fillTimers[modeId] and os.clock() >= fillTimers[modeId]
				if not filled and not timedOut then
					continue
				end
			end

			local since = readySince[modeId] or os.clock()
			if not readySince[modeId] then
				readySince[modeId] = since
			end

			if since < bestReadySince then
				bestReadySince = since
				bestModeId = modeId
			end
		end
	end

	if not bestModeId then
		return
	end

	local batch = takeReadyPlayers(bestModeId)
	if batch and #batch > 0 then
		startBatch(bestModeId, batch)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "Ungültiger Modus"
	end

	local mode = getMode(modeId)
	if not mode then
		return false, "Modus nicht gefunden"
	end

	if handlers.getPhase and handlers.getPhase(player) == "arena" then
		return false, "Du bist bereits in der Arena"
	end

	local existingMode = playerQueue[player]
	if existingMode == modeId then
		sendQueueUpdate(player)
		return true, "Bereits in der Warteschlange"
	end

	if existingMode then
		MatchmakingService.leaveQueue(player)
	end

	queues[modeId] = queues[modeId] or {}
	local queue = queues[modeId]

	if #queue >= mode.maxPlayers then
		return false, "Warteschlange voll"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	if #queue >= mode.minPlayers then
		if not readySince[modeId] then
			readySince[modeId] = os.clock()
		end
		maybeStartFillTimer(modeId)
	end

	broadcastQueue(modeId)
	MatchmakingService.tryStartMatch()

	return true, "Warteschlange beigetreten"
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player, modeId)
	broadcastQueue(modeId)
	sendQueueUpdate(player)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)

	for modeId in queues do
		broadcastQueue(modeId)
	end

	task.defer(MatchmakingService.tryStartMatch)
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.register(newHandlers)
	handlers = newHandlers or {}
end

function MatchmakingService.getRecommendedModeId()
	return MatchmakingConfig.getRecommendedModeId(#Players:GetPlayers())
end

task.spawn(function()
	while true do
		task.wait(1)
		if not MatchStateService.isArenaBusy() then
			for modeId in queues do
				local mode = getMode(modeId)
				local queue = queues[modeId]
				if mode and mode.fillTimeout and queue and #queue >= mode.minPlayers then
					maybeStartFillTimer(modeId)
					broadcastQueue(modeId)
				end
			end
			MatchmakingService.tryStartMatch()
		end
	end
end)

return MatchmakingService
