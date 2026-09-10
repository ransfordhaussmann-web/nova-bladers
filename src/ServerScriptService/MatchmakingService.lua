local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTimers = {}
local fillReady = {}

for modeId in pairs(MatchmakingConfig.MODES) do
	queues[modeId] = {}
end

local function mergePayload(base, extra)
	for key, value in extra do
		base[key] = value
	end
	return base
end

local function buildQueuePayload(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local players = {}
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			table.insert(players, queuedPlayer)
		end
	end
	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function sendQueueUpdate(player)
	local modeId = playerMode[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local status = if MatchStateService.isArenaBusy() then "pending" else "waiting"
	Remotes.QueueUpdate:FireClient(player, mergePayload({
		inQueue = true,
		status = status,
	}, buildQueuePayload(modeId)))
end

local function broadcastQueueUpdate(modeId)
	local status = if MatchStateService.isArenaBusy() then "pending" else "waiting"
	local payload = mergePayload({
		inQueue = true,
		status = status,
	}, buildQueuePayload(modeId))

	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent and playerMode[queuedPlayer] == modeId then
			Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
	fillReady[modeId] = false
end

local function pruneQueue(modeId)
	local cleaned = {}
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent and HubService.getPhase(queuedPlayer) == "hub" then
			table.insert(cleaned, queuedPlayer)
		else
			playerMode[queuedPlayer] = nil
		end
	end
	queues[modeId] = cleaned
end

local function popPlayers(modeId, count)
	pruneQueue(modeId)
	local picked = {}
	local remaining = {}
	for _, queuedPlayer in queues[modeId] do
		if #picked < count then
			table.insert(picked, queuedPlayer)
			playerMode[queuedPlayer] = nil
		else
			table.insert(remaining, queuedPlayer)
		end
	end
	queues[modeId] = remaining
	clearFillTimer(modeId)
	return picked
end

local function startMatchFromQueue(modeId, playerCount)
	local players = popPlayers(modeId, playerCount)
	if #players == 0 then
		return false
	end

	MatchStateService.setArenaBusy(true)
	for _, player in players do
		HubService.leaveHubForArena(player)
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
	end
	Bindables.MatchReady:Fire(players, modeId)
	broadcastQueueUpdate(modeId)
	return true
end

local function maybeScheduleFillTimer(modeId, mode, count)
	if not mode.fillTimeout or count < mode.minPlayers or count >= mode.maxPlayers then
		return
	end
	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		fillReady[modeId] = true
		MatchmakingService.tryStartMatches()
	end)
end

function MatchmakingService.tryStartMatches()
	if MatchStateService.isArenaBusy() then
		for modeId in pairs(MatchmakingConfig.MODES) do
			broadcastQueueUpdate(modeId)
		end
		return
	end

	for modeId, mode in pairs(MatchmakingConfig.MODES) do
		pruneQueue(modeId)
		local count = #queues[modeId]
		if count < mode.minPlayers then
			clearFillTimer(modeId)
			continue
		end

		if count >= mode.maxPlayers then
			startMatchFromQueue(modeId, mode.maxPlayers)
			return
		end

		if mode.minPlayers == mode.maxPlayers then
			if count >= mode.minPlayers then
				startMatchFromQueue(modeId, mode.minPlayers)
				return
			end
			continue
		end

		if fillReady[modeId] and count >= mode.minPlayers then
			fillReady[modeId] = false
			startMatchFromQueue(modeId, math.min(count, mode.maxPlayers))
			return
		end

		maybeScheduleFillTimer(modeId, mode, count)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end

	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	MatchmakingService.leaveQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
	MatchmakingService.tryStartMatches()
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	pruneQueue(modeId)
	clearFillTimer(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	MatchmakingService.tryStartMatches()
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.setupHubInteractions(hub)
	hub.portalPrompt.Triggered:Connect(function(player)
		local modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
		MatchmakingService.joinQueue(player, modeId)
	end)

	for _, pad in hub.modePads do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "JoinQueuePrompt"
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
end

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

return MatchmakingService
