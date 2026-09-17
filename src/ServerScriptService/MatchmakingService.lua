local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local starting = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
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

	if fillTimers[entry.modeId] and #queue < 2 then
		fillTimers[entry.modeId] = nil
	end

	playerQueue[player] = nil
end

local function getQueuePosition(modeId, player)
	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function getStatusMessage(mode, queueSize, arenaBusy)
	if arenaBusy then
		return "Arena belegt — Warteschlange aktiv"
	end
	if mode.id == "training" then
		return "Starte Training..."
	end
	if mode.id == "pvp" then
		if queueSize < 2 then
			return "Warte auf Gegner..."
		end
		return "Gegner gefunden!"
	end
	if queueSize < (mode.idealMin or mode.minPlayers) then
		return string.format("Warte auf Spieler (%d/%d)...", queueSize, mode.idealMin or mode.minPlayers)
	end
	return "Spieler gefunden!"
end

local function buildUpdatePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local queueSize = #queue
	local arenaBusy = MatchStateService.isArenaBusy()

	return {
		inQueue = true,
		modeId = mode.id,
		modeLabel = mode.label,
		position = getQueuePosition(mode.id, player),
		queueSize = queueSize,
		required = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		status = if arenaBusy then "pending" else "waiting",
		message = getStatusMessage(mode, queueSize, arenaBusy),
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildUpdatePayload(queuedPlayer))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local ready = {}

	for i = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[i]
		if player.Parent then
			table.insert(ready, player)
		end
	end

	return ready
end

local function clearQueue(modeId, players)
	local queue = getQueue(modeId)
	local removeSet = {}
	for _, player in players do
		removeSet[player] = true
	end

	for i = #queue, 1, -1 do
		if removeSet[queue[i]] then
			table.remove(queue, i)
		end
	end

	for _, player in players do
		playerQueue[player] = nil
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end

	fillTimers[modeId] = nil
end

local function shouldStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local size = #queue

	if size < mode.minPlayers then
		return false
	end

	if mode.id == "training" or mode.id == "pvp" then
		return size >= mode.maxPlayers
	end

	if size >= mode.maxPlayers then
		return true
	end

	if size >= (mode.idealMin or mode.minPlayers) then
		return true
	end

	local timerStart = fillTimers[modeId]
	if timerStart and os.clock() - timerStart >= MatchmakingConfig.FFA_FILL_TIMEOUT then
		return size >= mode.minPlayers
	end

	return false
end

local function tryStartMatch(modeId)
	if starting or MatchStateService.isArenaBusy() then
		return
	end

	if not shouldStartMatch(modeId) then
		return
	end

	local readyPlayers = collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	if #readyPlayers < mode.minPlayers then
		return
	end

	starting = true
	clearQueue(modeId, readyPlayers)
	broadcastAllQueues()

	task.delay(MatchmakingConfig.START_DELAY, function()
		starting = false
		if #readyPlayers == 0 then
			return
		end

		MatchStateService.setArenaBusy(true)
		MatchReady:Fire(readyPlayers, modeId)
	end)
end

local function updateFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local size = #queue

	if mode.id ~= "ffa" then
		return
	end

	if size >= 2 and size < (mode.idealMin or mode.minPlayers) then
		if not fillTimers[modeId] then
			fillTimers[modeId] = os.clock()
		end
	elseif size >= (mode.idealMin or mode.minPlayers) then
		fillTimers[modeId] = nil
	elseif size < 2 then
		fillTimers[modeId] = nil
	end
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	local queue = getQueue(modeId)
	local mode = MatchModes.get(modeId)

	if #queue >= mode.maxPlayers then
		return false
	end

	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }
	updateFillTimer(modeId)
	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

local function leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)
end

local function resolveQuickMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		broadcastAllQueues()
		for modeId in queues do
			tryStartMatch(modeId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for modeId in queues do
				updateFillTimer(modeId)
				tryStartMatch(modeId)
				broadcastQueue(modeId)
			end
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or modeId == "quick" then
		modeId = resolveQuickMode()
	end
	return joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

return MatchmakingService
