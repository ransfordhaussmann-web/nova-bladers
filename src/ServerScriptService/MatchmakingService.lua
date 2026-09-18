--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

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
local initialized = false

local function ensureModeQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureModeQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	fillTimers[modeId] = nil
end

local function getQueueNames(modeId)
	local names = {}
	for _, queuedPlayer in ensureModeQueue(modeId) do
		if isValidPlayer(queuedPlayer) then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end
	return names
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = ensureModeQueue(modeId)
	local count = #queue
	local status = "searching"

	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif mode and count >= mode.maxPlayers then
		status = "ready"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
		players = getQueueNames(modeId),
	}
end

local function broadcastQueueUpdate()
	for player in playerQueue do
		if isValidPlayer(player) then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function sendQueueUpdate(player)
	if isValidPlayer(player) then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.id ~= "ffa" then
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = ensureModeQueue(modeId)
	local readyPlayers = {}

	for _, queuedPlayer in queue do
		if isValidPlayer(queuedPlayer) then
			table.insert(readyPlayers, queuedPlayer)
		end
	end

	if #readyPlayers < mode.minPlayers then
		return
	end

	if #readyPlayers >= mode.maxPlayers then
		-- Full queue — start immediately.
	elseif mode.id == "ffa" then
		local deadline = fillTimers[modeId]
		if not deadline or os.clock() < deadline then
			if not deadline then
				startFillTimer(modeId)
			end
			return
		end
	else
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(#readyPlayers, mode.maxPlayers) do
		table.insert(matchPlayers, readyPlayers[i])
	end

	for _, matchPlayer in matchPlayers do
		removeFromQueue(matchPlayer)
	end

	fillTimers[modeId] = nil
	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(matchPlayers, modeId)
	broadcastQueueUpdate()
end

local function evaluateQueues()
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) or typeof(modeId) ~= "string" then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	removeFromQueue(player)

	local queue = ensureModeQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	if mode.id == "ffa" and #queue >= mode.minPlayers then
		startFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdate()
	evaluateQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdate()
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(evaluateQueues)
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			evaluateQueues()
		end
	end)
end

return MatchmakingService
