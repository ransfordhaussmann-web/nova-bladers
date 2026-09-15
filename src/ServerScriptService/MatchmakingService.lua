local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

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
local startingToken = 0
local callbacks = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function playerNamesInQueue(modeId)
	local names = {}
	for _, queuedPlayer in getQueue(modeId) do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.Name)
		end
	end
	return names
end

local function buildQueuePayload(player, modeId, status, extra)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local needed = mode.minPlayers

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		players = playerNamesInQueue(modeId),
		count = count,
		needed = needed,
		maxPlayers = mode.maxPlayers,
		arenaBusy = MatchStateService.isArenaBusy(),
		countdown = extra and extra.countdown,
		message = extra and extra.message,
	}
end

local function broadcastQueue(modeId)
	for _, queuedPlayer in getQueue(modeId) do
		if queuedPlayer.Parent and playerQueue[queuedPlayer] == modeId then
			local status = if MatchStateService.isArenaBusy() then "pending" else "waiting"
			local extra = {}
			local timer = fillTimers[modeId]
			if timer and not timer.cancelled and timer.endsAt then
				status = "filling"
				extra.countdown = math.max(0, math.ceil(timer.endsAt - os.clock()))
				extra.message = string.format("Match startet in %ds…", extra.countdown)
			elseif MatchStateService.isArenaBusy() then
				extra.message = "Arena belegt — Warteschlange pausiert"
			elseif #getQueue(modeId) >= MatchModes.get(modeId).minPlayers then
				extra.message = "Bereit — startet gleich…"
			else
				local missing = MatchModes.get(modeId).minPlayers - #getQueue(modeId)
				extra.message = string.format("Warte auf %d Spieler…", missing)
			end
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer, modeId, status, extra))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		if #getQueue(modeId) > 0 then
			broadcastQueue(modeId)
		end
	end
end

local function popPlayers(modeId, count)
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

local function fireMatchReady(players, modeId)
	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
	MatchReady:Fire(players, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if #queue < mode.minPlayers then
		return false
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end

	if fillTimers[modeId] then
		if #queue >= mode.maxPlayers then
			fillTimers[modeId].cancelled = true
			fillTimers[modeId] = nil
		else
			return false
		end
	end

	local playerCount = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, playerCount)

	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queue, player)
			playerQueue[player] = modeId
		end
		return false
	end

	startingToken += 1
	local token = startingToken
	MatchStateService.setArenaBusy(true)

	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, "starting", {
			message = "Match startet…",
		}))
	end

	task.delay(MatchmakingConfig.MATCH_READY_DELAY, function()
		if token ~= startingToken then
			return
		end

		local valid = {}
		for _, player in players do
			if player.Parent then
				table.insert(valid, player)
			end
		end

		if #valid < mode.minPlayers then
			MatchStateService.setArenaBusy(false)
			for _, player in valid do
				table.insert(queue, player)
				playerQueue[player] = modeId
			end
			broadcastQueue(modeId)
			MatchmakingService.onArenaFreed()
			return
		end

		fireMatchReady(valid, modeId)
	end)

	return true
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if mode.minPlayers == mode.maxPlayers then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	local timer = { cancelled = false }
	fillTimers[modeId] = timer
	timer.endsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT

	task.spawn(function()
		while not timer.cancelled do
			local remaining = timer.endsAt - os.clock()
			if remaining <= 0 then
				break
			end
			broadcastQueue(modeId)
			task.wait(1)
		end

		if timer.cancelled then
			return
		end

		fillTimers[modeId] = nil

		if #getQueue(modeId) >= mode.minPlayers and not MatchStateService.isArenaBusy() then
			tryStartMatch(modeId)
		else
			broadcastQueue(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if #queue == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	if #queue >= mode.maxPlayers then
		if fillTimers[modeId] then
			fillTimers[modeId].cancelled = true
			fillTimers[modeId] = nil
		end
		tryStartMatch(modeId)
		return
	end

	if #queue >= mode.minPlayers then
		if mode.minPlayers == mode.maxPlayers then
			tryStartMatch(modeId)
		else
			scheduleFillTimer(modeId)
		end
	else
		broadcastQueue(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue >= MatchModes.get(modeId).maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, "waiting", {
		message = "In Warteschlange…",
	}))

	evaluateQueue(modeId)
	broadcastQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	Remotes.QueueLeave:FireClient(player)
	broadcastQueue(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	broadcastAllQueues()
	for modeId in queues do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.start(options)
	callbacks = options or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastAllQueues()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
