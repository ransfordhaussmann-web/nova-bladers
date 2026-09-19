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
local pendingMatches = {}
local fillTimers = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getQueueStatus(modeId)
	local queue = ensureQueue(modeId)
	local mode = MatchModes.get(modeId)
	local count = #queue
	local fillTimeLeft = nil

	if mode and mode.fillTimeout > 0 and count >= mode.minPlayers and fillTimers[modeId] then
		fillTimeLeft = math.max(0, math.ceil(fillTimers[modeId] - os.clock()))
	end

	return {
		modeId = modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		fillTimeLeft = fillTimeLeft,
	}
end

local function buildPlayerUpdate(player, modeId, status)
	local queue = ensureQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = MatchModes.get(modeId).label,
		position = position,
		total = #queue,
		status = status,
		fillTimeLeft = getQueueStatus(modeId).fillTimeLeft,
	}
end

local function sendQueueUpdate(player, modeId, status)
	if player.Parent and Remotes.QueueUpdate then
		Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player, modeId, status))
	end
end

local function broadcastQueue(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		local status = if MatchStateService.isIdle() then "waiting" else "pending"
		sendQueueUpdate(player, modeId, status)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue < MatchModes.get(modeId).minPlayers then
		fillTimers[modeId] = nil
	end

	broadcastQueue(modeId)
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if mode.fillTimeout <= 0 then
		return count >= mode.minPlayers
	end

	if count >= mode.minPlayers then
		if not fillTimers[modeId] then
			fillTimers[modeId] = os.clock() + mode.fillTimeout
			broadcastQueue(modeId)
		end
		return os.clock() >= fillTimers[modeId]
	end

	return false
end

local function pullPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local matchPlayers = {}

	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
		playerQueue[player] = nil
	end

	fillTimers[modeId] = nil
	broadcastQueue(modeId)

	return matchPlayers
end

local function startMatch(modeId, matchPlayers)
	MatchStateService.setOccupied()

	for _, player in matchPlayers do
		if HubService.enterArena then
			HubService.enterArena(player)
		end
		sendQueueUpdate(player, modeId, "starting")
	end

	MatchReady:Fire(matchPlayers, modeId)
end

local function tryStartMode(modeId)
	if not canStartMode(modeId) then
		return
	end

	local matchPlayers = pullPlayers(modeId)
	if #matchPlayers == 0 then
		return
	end

	if MatchStateService.isIdle() then
		startMatch(modeId, matchPlayers)
	else
		table.insert(pendingMatches, {
			modeId = modeId,
			players = matchPlayers,
		})
		for _, player in matchPlayers do
			sendQueueUpdate(player, modeId, "pending")
		end
	end
end

local MODE_IDS = { "training", "pvp", "ffa" }

local function processQueues()
	for _, modeId in MODE_IDS do
		tryStartMode(modeId)
	end
end

local function processPending()
	if not MatchStateService.isIdle() or #pendingMatches == 0 then
		return
	end

	local nextMatch = table.remove(pendingMatches, 1)
	if nextMatch and #nextMatch.players > 0 then
		startMatch(nextMatch.modeId, nextMatch.players)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end

	if HubService.getPhase(player) == "arena" then
		return false, "in_match"
	end

	if playerQueue[player] == modeId then
		return true, "already_queued"
	end

	removeFromQueue(player)

	local queue = ensureQueue(modeId)
	if #queue >= MatchModes.get(modeId).maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	local status = if MatchStateService.isIdle() then "waiting" else "pending"
	sendQueueUpdate(player, modeId, status)
	tryStartMode(modeId)

	return true, status
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	if Remotes.QueueUpdate then
		Remotes.QueueUpdate:FireClient(player, { status = "left" })
	end
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setIdle()
	task.defer(processPending)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init()
	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady

	MatchStateService.onIdle(function()
		processPending()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)

		for i = #pendingMatches, 1, -1 do
			local match = pendingMatches[i]
			local filtered = {}
			for _, queuedPlayer in match.players do
				if queuedPlayer ~= player and queuedPlayer.Parent then
					table.insert(filtered, queuedPlayer)
				end
			end
			if #filtered == 0 then
				table.remove(pendingMatches, i)
			else
				match.players = filtered
			end
		end
	end)

	task.spawn(function()
		while true do
			processQueues()
			task.wait(MatchmakingConfig.FILL_CHECK_INTERVAL)
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
