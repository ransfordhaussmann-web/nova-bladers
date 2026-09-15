local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local fillTimers = {}
local fillTokens = {}
local callbacks = {}
local started = false

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function isPlayerInQueue(player)
	return playerEntry[player] ~= nil
end

local function removeFromQueueList(modeId, player)
	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			return
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillTimers[modeId] = nil
end

local function buildQueuePayload(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local size = getQueueSize(entry.modeId)

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		queueSize = size,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = entry.pending,
	}
end

local function sendQueueUpdate(player)
	if player.Parent and Remotes then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates()
	for player in playerEntry do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
		end
	end
	return picked
end

local function clearPlayerEntry(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end
	playerEntry[player] = nil
	removeFromQueueList(entry.modeId, player)
end

local function launchMatch(modeId, players)
	cancelFillTimer(modeId)

	for _, player in players do
		clearPlayerEntry(player)
	end

	MatchStateService.setBusy(true)

	if callbacks.onMatchLaunch then
		for _, player in players do
			callbacks.onMatchLaunch(player)
		end
	end

	MatchReady:Fire(players, modeId)
	broadcastQueueUpdates()
end

local function canStartNow(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return false
	end

	if mode.instantStart then
		return size >= mode.minPlayers
	end

	return size >= mode.maxPlayers
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.instantStart or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = true
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		fillTimers[modeId] = nil

		if MatchStateService.isBusy() then
			return
		end

		local size = getQueueSize(modeId)
		if size >= mode.minPlayers then
			local players = popPlayers(modeId, math.min(size, mode.maxPlayers))
			if #players >= mode.minPlayers then
				launchMatch(modeId, players)
			else
				for _, player in players do
					MatchmakingService.joinQueue(player, modeId)
				end
			end
		end
	end)
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if canStartNow(modeId) and (mode.instantStart or getQueueSize(modeId) >= mode.maxPlayers) then
		local players = popPlayers(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			launchMatch(modeId, players)
		end
		return
	end

	if not mode.instantStart and getQueueSize(modeId) >= mode.minPlayers then
		scheduleFillTimeout(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	if not isPlayerInQueue(player) then
		return
	end

	local entry = playerEntry[player]
	clearPlayerEntry(player)

	local mode = MatchModes.get(entry.modeId)
	if mode and not mode.instantStart and getQueueSize(entry.modeId) < mode.minPlayers then
		cancelFillTimer(entry.modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates()
end

function MatchmakingService.joinQueue(player, modeId)
	if callbacks.canJoin and not callbacks.canJoin(player) then
		return
	end

	if typeof(modeId) ~= "string" then
		modeId = MatchModes.recommendForPlayerCount(#Players:GetPlayers())
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if isPlayerInQueue(player) then
		MatchmakingService.leaveQueue(player)
	end

	local pending = MatchStateService.isBusy()
	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		pending = pending,
	}

	sendQueueUpdate(player)
	broadcastQueueUpdates()

	if not pending then
		tryStartMatch(modeId)
	end
end

function MatchmakingService.onArenaFree()
	MatchStateService.setBusy(false)

	for player, entry in playerEntry do
		if entry.pending then
			entry.pending = false
		end
	end

	broadcastQueueUpdates()

	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.start(opts)
	if started then
		return
	end
	started = true

	callbacks = opts or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
