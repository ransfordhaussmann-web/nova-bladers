local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local pendingMatch = nil

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {
			players = {},
			fillToken = 0,
			fillStartedAt = nil,
		}
	end
end

local function getQueueSize(modeId)
	return #queues[modeId].players
end

local function isPlayerInQueue(player)
	return playerQueue[player] ~= nil
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { status = "idle" }
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if pendingMatch and table.find(pendingMatch.players, player) then
		status = "pending"
	end

	return {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		fillElapsed = queue.fillStartedAt and (os.clock() - queue.fillStartedAt) or 0,
	}
end

local function sendQueueUpdate(player)
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if isPlayerInQueue(player) then
			sendQueueUpdate(player)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	local index = table.find(queue.players, player)
	if index then
		table.remove(queue.players, index)
	end
	playerQueue[player] = nil

	if #queue.players < MatchModes.get(modeId).minPlayers then
		queue.fillStartedAt = nil
		queue.fillToken += 1
	end

	if pendingMatch then
		local pendingIndex = table.find(pendingMatch.players, player)
		if pendingIndex then
			table.remove(pendingMatch.players, pendingIndex)
			if #pendingMatch.players == 0 then
				pendingMatch = nil
			end
		end
	end

	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	broadcastQueueUpdates()
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	if count < mode.minPlayers then
		return nil
	end

	local take = math.min(count, mode.maxPlayers)
	local ready = {}
	for i = 1, take do
		table.insert(ready, queue.players[i])
	end
	return ready
end

local function finalizeQueueStart(modeId, readyPlayers)
	local queue = queues[modeId]
	for _, player in readyPlayers do
		local index = table.find(queue.players, player)
		if index then
			table.remove(queue.players, index)
		end
		playerQueue[player] = nil
		Remotes.QueueUpdate:FireClient(player, { status = "starting", modeId = modeId })
	end

	queue.fillStartedAt = nil
	queue.fillToken += 1
	broadcastQueueUpdates()
	return readyPlayers
end

local function startMatch(readyPlayers, modeId)
	for _, player in readyPlayers do
		if HubService.leaveQueueForArena then
			HubService.leaveQueueForArena(player)
		end
	end
	Bindables.MatchReady:Fire(readyPlayers, modeId)
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local readyPlayers = collectReadyPlayers(modeId)
	if not readyPlayers then
		return
	end

	if MatchStateService.isMatchActive() then
		pendingMatch = {
			modeId = modeId,
			players = readyPlayers,
		}
		for _, player in readyPlayers do
			local index = table.find(queues[modeId].players, player)
			if index then
				table.remove(queues[modeId].players, index)
			end
			sendQueueUpdate(player)
		end
		broadcastQueueUpdates()
		return
	end

	local players = finalizeQueueStart(modeId, readyPlayers)
	startMatch(players, modeId)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	local queue = queues[modeId]
	queue.fillToken += 1
	local token = queue.fillToken
	queue.fillStartedAt = os.clock()

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		if #queue.players >= mode.minPlayers then
			tryStartMode(modeId)
		else
			queue.fillStartedAt = nil
		end
	end)
end

local function onQueueChanged(modeId)
	local mode = MatchModes.get(modeId)
	local count = getQueueSize(modeId)

	if count >= mode.maxPlayers then
		tryStartMode(modeId)
		return
	end

	if count >= mode.minPlayers and mode.fillTimeout <= 0 then
		tryStartMode(modeId)
		return
	end

	if count >= mode.minPlayers and mode.fillTimeout > 0 then
		local queue = queues[modeId]
		if not queue.fillStartedAt then
			scheduleFillTimeout(modeId)
		end
	end

	broadcastQueueUpdates()
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	if isPlayerInQueue(player) then
		if playerQueue[player] == modeId then
			sendQueueUpdate(player)
			return
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	onQueueChanged(modeId)
end

function MatchmakingService.joinAutoQueue(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.resolveAuto(count)
	MatchmakingService.joinQueue(player, mode.id)
end

function MatchmakingService.leaveQueue(player)
	if not isPlayerInQueue(player) then
		return
	end
	removeFromQueue(player)
end

local function processPendingMatch()
	if not pendingMatch or MatchStateService.isMatchActive() then
		return
	end

	local modeId = pendingMatch.modeId
	local readyPlayers = pendingMatch.players
	pendingMatch = nil

	local stillValid = {}
	for _, player in readyPlayers do
		if player.Parent and HubService.getPhase(player) ~= "arena" then
			table.insert(stillValid, player)
		end
	end

	local mode = MatchModes.get(modeId)
	if #stillValid < mode.minPlayers then
		for _, player in stillValid do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	local players = finalizeQueueStart(modeId, stillValid)
	startMatch(players, modeId)
end

function MatchmakingService.start(hub)
	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "auto" then
			MatchmakingService.joinAutoQueue(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	for _, pad in hub.modePads do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "QueuePrompt"
		prompt.ActionText = "Warteschlange"
		prompt.ObjectText = pad.config.label
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad.part

		prompt.Triggered:Connect(function(player)
			MatchmakingService.joinQueue(player, pad.config.id)
		end)
	end

	hub.portalPrompt.ActionText = "Warteschlange (Auto)"
	hub.portalPrompt.Triggered:Connect(function(player)
		MatchmakingService.joinAutoQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	MatchStateService.onMatchIdle(processPendingMatch)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastQueueUpdates()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
