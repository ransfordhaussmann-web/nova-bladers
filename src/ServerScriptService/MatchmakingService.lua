local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(script.Parent.MatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local callbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {
		players = {},
		fillToken = 0,
		fillTimerActive = false,
	}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueueList(queue, player)
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			return true
		end
	end
	return false
end

local function cancelFillTimer(queue)
	queue.fillToken += 1
	queue.fillTimerActive = false
end

local function getQueuePosition(queue, player)
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function buildStatusMessage(modeId, position, total, status)
	local mode = getModeConfig(modeId)
	if status == MatchmakingConfig.STATUS.PENDING then
		return "Arena belegt — du bist als Nächstes dran"
	end
	if status == MatchmakingConfig.STATUS.STARTING then
		return "Match startet..."
	end
	if modeId == "training" then
		return "Suche Trainingsplatz..."
	end
	if modeId == "pvp" then
		if total < mode.minPlayers then
			return string.format("Warte auf Gegner (%d/%d)", total, mode.minPlayers)
		end
		return "Gegner gefunden!"
	end
	if total < mode.minPlayers then
		return string.format("Warte auf Spieler (%d/%d)", total, mode.minPlayers)
	end
	return string.format("Lobby füllt sich (%d/%d)", total, mode.maxPlayers)
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local queue = queues[modeId]
	local position = getQueuePosition(queue, player) or 1
	local total = #queue.players
	local status = MatchmakingConfig.STATUS.WAITING
	if MatchState.isBusy() then
		status = MatchmakingConfig.STATUS.PENDING
	end

	local mode = getModeConfig(modeId)
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		total = total,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		message = buildStatusMessage(modeId, position, total, status),
	})
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	for _, player in queue.players do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			table.insert(taken, player)
			playerQueue[player] = nil
		end
	end
	cancelFillTimer(queue)
	return taken
end

local function markStarting(players)
	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = true,
			status = MatchmakingConfig.STATUS.STARTING,
			message = "Match startet...",
		})
	end
end

local function startMatch(modeId)
	if MatchState.isBusy() then
		return
	end

	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue.players < mode.minPlayers then
		return
	end

	local playerCount = math.min(#queue.players, mode.maxPlayers)
	local players = takePlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queue.players, player)
			playerQueue[player] = modeId
		end
		return
	end

	MatchState.setBusy(true)
	markStarting(players)

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end

	Bindables.MatchReady:Fire(players, modeId)
	broadcastQueue(modeId)
end

local function scheduleFillTimer(modeId)
	local mode = getModeConfig(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	local queue = queues[modeId]
	if queue.fillTimerActive then
		return
	end

	queue.fillTimerActive = true
	local token = queue.fillToken + 1
	queue.fillToken = token

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		queue.fillTimerActive = false
		if #queue.players >= mode.minPlayers then
			startMatch(modeId)
		end
	end)
end

local MODE_ORDER = { "training", "pvp", "ffa" }

function MatchmakingService.tryStartAll()
	if MatchState.isBusy() then
		return
	end

	for _, modeId in MODE_ORDER do
		local mode = getModeConfig(modeId)
		local queue = queues[modeId]
		local count = #queue.players
		if count >= mode.maxPlayers then
			startMatch(modeId)
			return
		end
		if count >= mode.minPlayers then
			if mode.fillTimeout > 0 then
				scheduleFillTimer(modeId)
			else
				startMatch(modeId)
				return
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if MatchmakingService.isQueued(player) then
		if playerQueue[player] == modeId then
			sendQueueUpdate(player)
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueue(modeId)
	MatchmakingService.tryStartAll()
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local queue = queues[modeId]
	removeFromQueueList(queue, player)
	playerQueue[player] = nil
	cancelFillTimer(queue)

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)
	MatchmakingService.tryStartAll()
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchState.setBusy(false)
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
	end
	task.defer(MatchmakingService.tryStartAll)
end

function MatchmakingService.register(newCallbacks)
	for key, handler in newCallbacks do
		callbacks[key] = handler
	end
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

return MatchmakingService
