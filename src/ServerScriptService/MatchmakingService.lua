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
local fillTimers = {}
local started = false

local function initQueues()
	for _, modeId in MatchModes.getOrdered() do
		queues[modeId] = {}
	end
end

local function getQueueCount(modeId)
	local count = 0
	for player in queues[modeId] do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function getQueuePlayers(modeId)
	local list = {}
	for player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function getFillRemaining(modeId)
	local timer = fillTimers[modeId]
	if not timer then
		return nil
	end
	return math.max(0, math.ceil(timer.endsAt - os.clock()))
end

local function buildUpdateForPlayer(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif mode.fillTimeout and count >= mode.minPlayers then
		status = "filling"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillRemaining = getFillRemaining(modeId),
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function broadcastQueueUpdate()
	for player in playerQueue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdateForPlayer(player))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	queues[modeId][player] = nil
	playerQueue[player] = nil
	clearFillTimer(modeId)

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local players = getQueuePlayers(modeId)
	local count = #players

	if count < mode.minPlayers then
		return false, players
	end

	if mode.fillTimeout then
		local timer = fillTimers[modeId]
		if count >= mode.maxPlayers then
			return true, players
		end
		if timer and os.clock() >= timer.endsAt then
			return true, players
		end
		return false, players
	end

	return true, players
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = {
		endsAt = os.clock() + mode.fillTimeout,
	}
end

local function launchMatch(modeId, players)
	for _, player in players do
		removeFromQueue(player)
		HubService.enterArena(player)
	end

	Bindables.MatchReady:Fire(players, modeId)
end

local function tryStartMatches()
	if MatchStateService.isBusy() then
		return
	end

	for _, modeId in MatchModes.getOrdered() do
		local ready, players = canStartMode(modeId)
		if ready and #players > 0 then
			launchMatch(modeId, players)
			return
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end

	if HubService.getPhase(player) == "arena" then
		return false
	end

	removeFromQueue(player)

	queues[modeId][player] = true
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	if mode.fillTimeout and count >= mode.minPlayers then
		startFillTimer(modeId)
	end

	Remotes.QueueUpdate:FireClient(player, buildUpdateForPlayer(player))
	broadcastQueueUpdate()
	tryStartMatches()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	broadcastQueueUpdate()
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setMatchActive(false)
	task.defer(tryStartMatches)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			if next(playerQueue) then
				broadcastQueueUpdate()
				tryStartMatches()
			end
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
