local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerMode = {}
local ffaTimers = {}
local pendingMatch = nil
local started = false

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function playerInQueue(player)
	return playerMode[player] ~= nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil

	if modeId == "ffa" and #queue == 0 and ffaTimers[modeId] then
		ffaTimers[modeId].cancelled = true
		ffaTimers[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId, status)
	local config = getModeConfig(modeId)
	local count = queueCount(modeId)
	local timer = ffaTimers[modeId]

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		playersInQueue = count,
		playersNeeded = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status or "waiting",
		fillCountdown = timer and timer.remaining or nil,
	}
end

local function sendQueueUpdate(player, modeId, status)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
	end
end

local function broadcastQueueUpdate(modeId)
	local status = GameMatchState.isArenaBusy() and "pending" or "waiting"
	for _, queuedPlayer in queues[modeId] do
		sendQueueUpdate(queuedPlayer, modeId, status)
	end
end

local function clearQueueState(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function transitionToArena(playerList)
	for _, player in playerList do
		if HubService.getPhase(player) ~= "arena" then
			HubService.enterArena(player)
		end
	end
end

local function launchMatch(playerList)
	GameMatchState.setArenaBusy(true)
	pendingMatch = nil
	for _, player in playerList do
		clearQueueState(player)
	end
	transitionToArena(playerList)
	Bindables.MatchReady:Fire(playerList)
end

local function tryStartMode(modeId)
	local config = getModeConfig(modeId)
	local count = queueCount(modeId)

	if count < config.minPlayers then
		return false
	end

	if GameMatchState.isArenaBusy() then
		if not pendingMatch or pendingMatch.modeId ~= modeId then
			pendingMatch = {
				modeId = modeId,
				playerCount = math.min(count, config.maxPlayers),
			}
		end
		broadcastQueueUpdate(modeId)
		return false
	end

	local takeCount = math.min(count, config.maxPlayers)
	local playerList = popPlayers(modeId, takeCount)

	if #playerList < config.minPlayers then
		for _, player in playerList do
			table.insert(queues[modeId], player)
			playerMode[player] = modeId
		end
		return false
	end

	if modeId == "ffa" and ffaTimers[modeId] then
		ffaTimers[modeId].cancelled = true
		ffaTimers[modeId] = nil
	end

	launchMatch(playerList)
	return true
end

local function startFfaTimer()
	local modeId = "ffa"
	if ffaTimers[modeId] then
		return
	end

	local config = getModeConfig(modeId)
	local token = { cancelled = false, remaining = config.fillTimeout }
	ffaTimers[modeId] = token

	task.spawn(function()
		while token.remaining > 0 and not token.cancelled do
			broadcastQueueUpdate(modeId)
			task.wait(1)
			token.remaining -= 1
		end

		if token.cancelled then
			return
		end

		ffaTimers[modeId] = nil
		tryStartMode(modeId)
	end)
end

local function onArenaFree()
	GameMatchState.setArenaBusy(false)

	if pendingMatch then
		local modeId = pendingMatch.modeId
		pendingMatch = nil
		tryStartMode(modeId)
		return
	end

	for modeId in MatchmakingConfig.MODES do
		if tryStartMode(modeId) then
			break
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not isValidMode(modeId) then
		return false
	end

	if HubService.getPhase(player) == "arena" then
		return false
	end

	if playerInQueue(player) then
		if playerMode[player] == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	local status = GameMatchState.isArenaBusy() and "pending" or "waiting"
	sendQueueUpdate(player, modeId, status)
	broadcastQueueUpdate(modeId)

	local config = getModeConfig(modeId)
	if modeId == "ffa" and queueCount(modeId) >= config.minPlayers and not ffaTimers[modeId] then
		startFfaTimer()
	end

	if tryStartMode(modeId) then
		return true
	end

	if modeId == "ffa" and queueCount(modeId) >= config.maxPlayers then
		tryStartMode(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	clearQueueState(player)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
