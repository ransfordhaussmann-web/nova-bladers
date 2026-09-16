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
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getQueuePosition(modeId, player)
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local pending = MatchStateService.isArenaBusy()

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = getQueuePosition(modeId, player),
		pending = pending,
		statusText = pending
			? "Arena belegt — warte auf freies Match"
			: string.format("%d / %d Spieler", #queue, mode.minPlayers),
	}
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
end

local function broadcastQueueUpdates()
	for player in playerQueue do
		sendQueueUpdate(player)
	end
end

local function cancelFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	local mode = MatchModes.get(modeId)
	if mode.fillTimeout and #queue < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	if not silent then
		broadcastQueueUpdates()
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
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

local function launchMatch(modeId, playerList)
	cancelFillTimer(modeId)
	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		if HubService.getPhase(player) ~= "arena" then
			HubService.leaveHubForArena(player)
		end
	end

	MatchReady:Fire(modeId, playerList)
	broadcastQueueUpdates()
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates()
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout then
		if #queue >= mode.maxPlayers then
			launchMatch(modeId, popPlayers(modeId, mode.maxPlayers))
			return
		end

		if not fillTimers[modeId] then
			local token = {}
			fillTimers[modeId] = token
			task.delay(mode.fillTimeout, function()
				if fillTimers[modeId] ~= token then
					return
				end
				fillTimers[modeId] = nil
				if MatchStateService.isArenaBusy() then
					broadcastQueueUpdates()
					return
				end
				local currentQueue = queues[modeId]
				if #currentQueue >= mode.minPlayers then
					launchMatch(modeId, popPlayers(modeId, math.min(#currentQueue, mode.maxPlayers)))
				end
			end)
		end
		return
	end

	launchMatch(modeId, popPlayers(modeId, mode.minPlayers))
end

local function joinQueue(player, modeId)
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

	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player, true)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	sendQueueUpdate(player)
	broadcastQueueUpdates()
	tryStartMatch(modeId)
end

local function leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player)
		return
	end
	removeFromQueue(player, false)
	sendQueueUpdate(player)
end

local function onArenaFreed()
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.joinRecommended(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.recommendForPlayerCount(count)
	joinQueue(player, mode.id)
end

function MatchmakingService.joinMode(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leave(player)
	leaveQueue(player)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(onArenaFreed)
end

function MatchmakingService.setupModePads(modePads)
	for _, pad in modePads do
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
			joinQueue(player, pad.config.id)
		end)
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	initQueues()

	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == nil or modeId == "auto" then
			MatchmakingService.joinRecommended(player)
		else
			joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			if MatchStateService.isArenaBusy() then
				broadcastQueueUpdates()
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

function MatchmakingService.getMatchReadyEvent()
	return MatchReady
end

return MatchmakingService
