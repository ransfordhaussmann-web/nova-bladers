local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerMode = {}
local fillTokens = {}
local pendingModes = {}
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function isValidPlayer(player)
	return player and player.Parent and HubService.getPhase(player) == "hub"
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local cleaned = {}
	for _, player in queue do
		if isValidPlayer(player) then
			table.insert(cleaned, player)
		else
			playerMode[player] = nil
		end
	end
	queues[modeId] = cleaned
	return cleaned
end

local function buildUpdatePayload(modeId, status)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = pruneQueue(modeId)
	local count = #queue
	local needed = mode.minPlayers
	local payload = {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		needed = needed,
		max = mode.maxPlayers,
		status = status or "waiting",
	}

	if status == "pending" then
		payload.detail = "Arena belegt — warte auf freien Slot"
	elseif count >= needed then
		payload.detail = string.format("%d/%d Spieler bereit", count, mode.maxPlayers)
	else
		payload.detail = string.format("%d/%d Spieler in Warteschlange", count, needed)
	end

	return payload
end

local function broadcastQueue(modeId, status)
	local payload = buildUpdatePayload(modeId, status)
	for _, player in getQueue(modeId) do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		if #getQueue(modeId) > 0 then
			local status = pendingModes[modeId] and "pending" or "waiting"
			broadcastQueue(modeId, status)
		end
	end
end

local function removeFromAllQueues(player)
	for modeId in MatchmakingConfig.MODES do
		local queue = getQueue(modeId)
		for i = #queue, 1, -1 do
			if queue[i] == player then
				table.remove(queue, i)
			end
		end
	end
	playerMode[player] = nil
end

local function markPlayersArena(players)
	for _, player in players do
		if HubService.markArena then
			HubService.markArena(player)
		end
	end
end

local function startMatch(modeId, players)
	pendingModes[modeId] = nil
	local queue = getQueue(modeId)
	for _, player in players do
		for i = #queue, 1, -1 do
			if queue[i] == player then
				table.remove(queue, i)
			end
		end
		playerMode[player] = nil
	end

	markPlayersArena(players)

	for _, player in players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = modeId,
				modeLabel = MatchmakingConfig.getMode(modeId).label,
				count = #players,
				needed = MatchmakingConfig.getMode(modeId).minPlayers,
				max = MatchmakingConfig.getMode(modeId).maxPlayers,
				status = "starting",
				detail = "Match startet…",
			})
		end
	end

	GameMatchState.setArenaBusy(true)
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = players,
	})
end

local function tryStartMode(modeId)
	if GameMatchState.isArenaBusy() then
		pendingModes[modeId] = true
		broadcastQueue(modeId, "pending")
		return false
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = pruneQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	local players = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(players, queue[i])
	end

	for _, player in players do
		for i = #queue, 1, -1 do
			if queue[i] == player then
				table.remove(queue, i)
			end
		end
	end

	startMatch(modeId, players)
	return true
end

local function scheduleFillTimeout(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	local mode = MatchmakingConfig.getMode(modeId)

	if mode.fillTimeout <= 0 then
		tryStartMode(modeId)
		return
	end

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		local queue = pruneQueue(modeId)
		if #queue >= mode.minPlayers then
			tryStartMode(modeId)
		end
	end)
end

local function onQueueChanged(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = pruneQueue(modeId)

	if #queue == 0 then
		pendingModes[modeId] = nil
		fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
		return
	end

	broadcastQueue(modeId, pendingModes[modeId] and "pending" or "waiting")

	if #queue >= mode.maxPlayers then
		tryStartMode(modeId)
		return
	end

	if #queue >= mode.minPlayers and modeId ~= "ffa" then
		tryStartMode(modeId)
		return
	end

	if #queue == mode.minPlayers and modeId == "ffa" then
		scheduleFillTimeout(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	if playerMode[player] then
		MatchmakingService.leaveQueue(player)
	end

	removeFromAllQueues(player)
	table.insert(getQueue(modeId), player)
	playerMode[player] = modeId

	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromAllQueues(player)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	pendingModes[modeId] = nil

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, {
			status = "left",
		})
	end

	onQueueChanged(modeId)
end

function MatchmakingService.resolveQuickMode()
	return MatchmakingConfig.resolveQuickMode(#Players:GetPlayers())
end

function MatchmakingService.onArenaFree()
	for modeId in MatchmakingConfig.MODES do
		if pendingModes[modeId] or #getQueue(modeId) > 0 then
			if tryStartMode(modeId) then
				return
			end
		end
	end
	broadcastAllQueues()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			modeId = MatchmakingService.resolveQuickMode()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerMode[player]
		if modeId then
			removeFromAllQueues(player)
			onQueueChanged(modeId)
		end
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready (Training / PvP / FFA)")
end

return MatchmakingService
