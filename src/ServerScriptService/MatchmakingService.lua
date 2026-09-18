--[[
	MatchmakingService — Queue pro Modus, startet Matches via MatchReady-Bindable.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local fillTimers = {}
local readyToStart = {}
local handlers = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end
	return queues[modeId]
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local cleaned = {}
	for _, player in queue.players do
		if player.Parent and playerEntry[player] and playerEntry[player].modeId == modeId then
			table.insert(cleaned, player)
		end
	end
	queue.players = cleaned
end

local function buildQueuePayload(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	pruneQueue(entry.modeId)

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		playersWaiting = #queue.players,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		pending = entry.pending or MatchStateService.isBusy(),
	}
end

local function broadcastQueueUpdate()
	for player, _ in playerEntry do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
	readyToStart[modeId] = false
end

local function startFillTimer(modeId, mode)
	clearFillTimer(modeId)
	local token = {}
	fillTimers[modeId] = token

	local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT
	task.delay(timeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		readyToStart[modeId] = true
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		for _, entry in playerEntry do
			if entry.modeId == modeId then
				entry.pending = true
			end
		end
		broadcastQueueUpdate()
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	pruneQueue(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end

	local takeCount = math.min(count, mode.maxPlayers)
	if takeCount < mode.maxPlayers and mode.fillTimeout and fillTimers[modeId] and not readyToStart[modeId] then
		return false
	end

	local matchPlayers = {}
	for i = 1, takeCount do
		table.insert(matchPlayers, queue.players[i])
	end

	if #matchPlayers == 0 then
		return false
	end

	fillTimers[modeId] = nil
	readyToStart[modeId] = false

	for _, player in matchPlayers do
		playerEntry[player] = nil
	end

	local remaining = {}
	for i = takeCount + 1, #queue.players do
		table.insert(remaining, queue.players[i])
	end
	queue.players = remaining

	if handlers.onMatchForming then
		handlers.onMatchForming(matchPlayers, modeId)
	end

	MatchStateService.setBusy()
	Bindables.MatchReady:Fire({
		players = matchPlayers,
		modeId = modeId,
	})

	broadcastQueueUpdate()

	for _, otherModeId in MatchModes.ids() do
		MatchmakingService.evaluateQueue(otherModeId)
	end

	return true
end

function MatchmakingService.evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players

	if count >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if count >= mode.minPlayers then
		if mode.fillTimeout then
			if readyToStart[modeId] or not fillTimers[modeId] then
				if readyToStart[modeId] then
					MatchmakingService.tryStartMatch(modeId)
				elseif not fillTimers[modeId] then
					startFillTimer(modeId, mode)
				end
			end
		else
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	MatchmakingService.leaveQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerEntry[player] = {
		modeId = modeId,
		pending = MatchStateService.isBusy(),
	}

	if handlers.onQueueJoin then
		handlers.onQueueJoin(player, modeId)
	end

	broadcastQueueUpdate()
	MatchmakingService.evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerEntry[player] = nil
	pruneQueue(entry.modeId)

	local mode = MatchModes.get(entry.modeId)
	if mode and #getQueue(entry.modeId).players < mode.minPlayers then
		clearFillTimer(entry.modeId)
	end

	broadcastQueueUpdate()
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId
end

function MatchmakingService.init(newHandlers)
	handlers = newHandlers or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onIdle(function()
		for player, entry in playerEntry do
			entry.pending = false
		end
		broadcastQueueUpdate()

		for _, modeId in MatchModes.ids() do
			MatchmakingService.evaluateQueue(modeId)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
