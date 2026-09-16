local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local MatchReadyBindable

local queues = {}
local playerQueue = {}
local playerPending = {}
local fillTimers = {}
local pendingMatch = nil
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getQueueCount(modeId)
	return #(queues[modeId] or {})
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player] or playerPending[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	local pending = playerPending[player] ~= nil or MatchStateService.isBusy()

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		players = count,
		needed = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		pending = pending,
		status = pending and "Warte auf freie Arena…" or "Suche Mitspieler…",
	}
end

local function broadcastQueue(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllQueued()
	for player in playerQueue do
		broadcastQueue(player)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	playerPending[player] = nil
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local list = queues[modeId]
	for i, p in list do
		if p == player then
			table.remove(list, i)
			break
		end
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	if pendingMatch then
		local remaining = {}
		for _, p in pendingMatch.players do
			if p ~= player and p.Parent then
				table.insert(remaining, p)
			end
		end
		local mode = MatchModes.get(pendingMatch.modeId)
		if #remaining < (mode and mode.minPlayers or 1) then
			pendingMatch = nil
			for _, p in remaining do
				playerPending[p] = nil
				broadcastQueue(p)
			end
		else
			pendingMatch.players = remaining
		end
	end

	broadcastQueue(player)
	broadcastAllQueued()
end

local function leaveHubForMatch(players)
	if MatchmakingService.onMatchStarting then
		MatchmakingService.onMatchStarting(players)
	end
end

local function launchMatch(modeId, matchedPlayers)
	if MatchStateService.isBusy() then
		pendingMatch = { modeId = modeId, players = matchedPlayers }
		for _, player in matchedPlayers do
			playerPending[player] = modeId
			broadcastQueue(player)
		end
		return
	end

	for _, player in matchedPlayers do
		playerPending[player] = nil
		removeFromQueue(player)
	end

	leaveHubForMatch(matchedPlayers)
	MatchReadyBindable:Fire(matchedPlayers)
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local count = getQueueCount(modeId)
	return count >= mode.minPlayers
end

local function tryStartMode(modeId)
	if not canStartMode(modeId) then
		return
	end

	local mode = MatchModes.get(modeId)
	local list = queues[modeId]
	local matched = {}
	for i = 1, math.min(#list, mode.maxPlayers) do
		table.insert(matched, list[i])
	end

	if #matched < mode.minPlayers then
		return
	end

	launchMatch(modeId, matched)
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local mode = MatchModes.get(modeId)
	if mode.id ~= "ffa" then
		return
	end

	fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers[modeId] = nil
		tryStartMode(modeId)
	end)
end

local function joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueue(player)
	broadcastAllQueued()

	if modeId == "training" or modeId == "pvp" then
		tryStartMode(modeId)
	elseif modeId == "ffa" then
		if getQueueCount(modeId) >= mode.maxPlayers then
			if fillTimers[modeId] then
				task.cancel(fillTimers[modeId])
				fillTimers[modeId] = nil
			end
			tryStartMode(modeId)
		elseif getQueueCount(modeId) >= mode.minPlayers then
			startFillTimer(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not started then
		return
	end
	joinQueue(player, modeId or getRecommendedModeId())
end

function MatchmakingService.leaveQueue(player)
	if not started then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.onArenaFreed()
	if pendingMatch and not MatchStateService.isBusy() then
		local match = pendingMatch
		pendingMatch = nil
		for _, player in match.players do
			playerPending[player] = nil
			removeFromQueue(player)
		end
		leaveHubForMatch(match.players)
		MatchReadyBindable:Fire(match.players)
	end

	for modeId, _ in queues do
		if canStartMode(modeId) then
			tryStartMode(modeId)
		end
	end
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.start(hub)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReadyBindable = Bindables.MatchReady

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = getRecommendedModeId()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		removeFromQueue(player)
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end)

	if hub.portalPrompt then
		hub.portalPrompt.Triggered:Connect(function(player)
			joinQueue(player, getRecommendedModeId())
		end)
	end

	for _, pad in hub.modePads do
		local prompt = pad.part:FindFirstChild("JoinQueuePrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				joinQueue(player, pad.config.id)
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue ready — portal, mode pads, and lobby button")
end

return MatchmakingService
