local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queued = queues[modeId] or {}
	local names = {}
	for _, p in queued do
		if p.Parent then
			table.insert(names, p.DisplayName)
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		queued = #names,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		playerNames = names,
		status = status,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId, nil)
	for _, player in Players:GetPlayers() do
		if playerQueue[player] == modeId or HubService.getPhase(player) == "hub" then
			local personal = buildQueuePayload(modeId, player)
			Remotes.QueueUpdate:FireClient(player, personal)
		end
	end
end

local function broadcastAllQueues()
	for _, mode in MatchModes.all() do
		broadcastQueue(mode.id)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, p in queue do
			if p == player then
				table.remove(queue, i)
				break
			end
		end
	end
	playerQueue[player] = nil
	broadcastQueue(modeId)
end

local function addToQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	if MatchStateService.isArenaBusy() then
		playerQueue[player] = modeId
		table.insert(queues[modeId], player)
		broadcastQueue(modeId)
		return true, "pending"
	end

	playerQueue[player] = modeId
	table.insert(queues[modeId], player)
	broadcastQueue(modeId)

	if mode.startImmediately and #queues[modeId] >= mode.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	end

	return true, "joined"
end

local function collectValidPlayers(modeId)
	local queue = queues[modeId]
	local valid = {}
	for _, player in queue do
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(valid, player)
		end
	end
	return valid
end

local function clearQueue(modeId)
	queues[modeId] = {}
	for player, queuedMode in playerQueue do
		if queuedMode == modeId then
			playerQueue[player] = nil
		end
	end
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local players = collectValidPlayers(modeId)
	if #players < mode.minPlayers then
		return
	end

	if #players > mode.maxPlayers then
		local trimmed = {}
		for i = 1, mode.maxPlayers do
			trimmed[i] = players[i]
		end
		players = trimmed
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	MatchStateService.setArenaBusy(true)
	clearQueue(modeId)
	broadcastAllQueues()

	for _, player in players do
		playerQueue[player] = nil
		if HubService.leaveHubForArena then
			HubService.leaveHubForArena(player)
		end
	end

	task.delay(MatchmakingConfig.MATCH_READY_DELAY, function()
		if token ~= fillTokens[modeId] then
			return
		end
		MatchReady:Fire(players, modeId)
	end)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if MatchStateService.isArenaBusy() then
			return
		end
		local players = collectValidPlayers(modeId)
		if #players >= mode.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

local function onQueueJoin(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	local ok, reason = addToQueue(player, modeId)
	if not ok then
		return
	end

	local mode = MatchModes.get(modeId)
	if reason == "joined" and mode and not mode.startImmediately then
		local queue = queues[modeId]
		if #queue >= mode.minPlayers and #queue <= mode.maxPlayers then
			if #queue == mode.maxPlayers then
				MatchmakingService.tryStartMatch(modeId)
			elseif mode.id == "pvp" and #queue >= 2 then
				MatchmakingService.tryStartMatch(modeId)
			elseif mode.id == "ffa" and #queue >= mode.minPlayers then
				scheduleFillTimeout(modeId)
			end
		elseif mode.id == "ffa" and #queue >= 1 and #queue < mode.minPlayers then
			scheduleFillTimeout(modeId)
		end
	end
end

local function onQueueLeave(player)
	removeFromQueue(player)
end

function MatchmakingService.joinQueue(player, modeId)
	onQueueJoin(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	onQueueLeave(player)
end

local function evaluateQueuesAfterMatch()
	for _, mode in MatchModes.all() do
		local players = collectValidPlayers(mode.id)
		if #players == 0 then
			continue
		end
		if mode.startImmediately and #players >= mode.minPlayers then
			MatchmakingService.tryStartMatch(mode.id)
		elseif mode.id == "pvp" and #players >= 2 then
			MatchmakingService.tryStartMatch(mode.id)
		elseif mode.id == "ffa" and #players >= mode.minPlayers then
			scheduleFillTimeout(mode.id)
		end
	end
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	broadcastAllQueues()
	evaluateQueuesAfterMatch()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(onQueueJoin)
	Remotes.QueueLeave.OnServerEvent:Connect(onQueueLeave)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
