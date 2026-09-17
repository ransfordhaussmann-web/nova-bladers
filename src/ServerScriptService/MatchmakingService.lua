local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReadyBindable

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local pendingStarts = {}
local started = false

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
		local mode = MatchModes.get(modeId)
		if mode and #queue < mode.minPlayers then
			fillTimers[modeId] = nil
		end
	end
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = getQueue(modeId)
	local message
	if status == "pending" then
		message = MatchmakingConfig.PENDING_MESSAGE
	elseif status == "starting" then
		message = MatchmakingConfig.STARTING_MESSAGE
	elseif #queue < mode.minPlayers then
		message = string.format("Warte auf Spieler (%d/%d)…", #queue, mode.minPlayers)
	else
		message = string.format("Lobby voll (%d/%d)", #queue, mode.maxPlayers)
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		message = message,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates()
	for modeId, queue in pairs(queues) do
		local status = pendingStarts[modeId] and "pending" or "waiting"
		for _, player in queue do
			sendQueueUpdate(player, buildQueuePayload(player, modeId, status))
		end
	end
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local ready = {}

	for i = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[i]
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(ready, player)
		end
	end

	return ready
end

local function clearQueue(modeId, matchedPlayers)
	local queue = getQueue(modeId)
	local matchedSet = {}
	for _, player in matchedPlayers do
		matchedSet[player] = true
	end

	for i = #queue, 1, -1 do
		local player = queue[i]
		if matchedSet[player] then
			table.remove(queue, i)
			playerQueue[player] = nil
			sendQueueUpdate(player, { inQueue = false })
		end
	end

	fillTimers[modeId] = nil
	pendingStarts[modeId] = nil
end

local function launchMatch(modeId, matchedPlayers)
	if #matchedPlayers == 0 then
		return
	end

	for _, player in matchedPlayers do
		HubService.enterArena(player)
		sendQueueUpdate(player, buildQueuePayload(player, modeId, "starting"))
	end

	clearQueue(modeId, matchedPlayers)
	MatchStateService.setBusy()
	MatchReadyBindable:Fire(matchedPlayers)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local ready = collectReadyPlayers(modeId)
	if #ready < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		pendingStarts[modeId] = ready
		broadcastQueueUpdates()
		return
	end

	launchMatch(modeId, ready)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = os.clock()
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function onPlayerJoinedQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	sendQueueUpdate(player, buildQueuePayload(player, modeId, "waiting"))
	broadcastQueueUpdates()

	if #queue >= mode.minPlayers then
		if mode.fillTimeout and #queue < mode.maxPlayers then
			scheduleFillTimeout(modeId)
		else
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue >= MatchModes.get(modeId).maxPlayers then
		return false
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	onPlayerJoinedQueue(player, modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	removeFromQueue(player)
	sendQueueUpdate(player, { inQueue = false })
	broadcastQueueUpdates()
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local modeId = "training"
	if count >= 3 then
		modeId = "ffa"
	elseif count == 2 then
		modeId = "pvp"
	end
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setIdle()

	for modeId, ready in pairs(pendingStarts) do
		if ready and #ready > 0 then
			pendingStarts[modeId] = nil
			launchMatch(modeId, ready)
			return
		end
	end

	for modeId in pairs(queues) do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start(remotes, bindables)
	if started then
		return
	end
	started = true

	Remotes = remotes
	MatchReadyBindable = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinQuickMatch(player)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			broadcastQueueUpdates()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
