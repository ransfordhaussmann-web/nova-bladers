local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady
local ArenaFree

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local ffaReadyToStart = false
local started = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromList(list, player)
	for i = #list, 1, -1 do
		if list[i] == player then
			table.remove(list, i)
		end
	end
end

local function getQueueCount(modeId)
	local count = 0
	for player, queuedMode in playerQueue do
		if queuedMode == modeId and player.Parent then
			count += 1
		end
	end
	return count
end

local function buildQueuePayload(targetPlayer)
	local modeId = playerQueue[targetPlayer]
	if not modeId then
		return { inQueue = false }
	end

	local config = getModeConfig(modeId)
	local counts = {}
	for id in MatchmakingConfig.MODES do
		counts[id] = getQueueCount(id)
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		playersInQueue = counts[modeId],
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		pending = GameMatchState.isBusy(),
	}
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
end

local function broadcastQueueUpdates()
	for player, _ in playerQueue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function pruneInvalidPlayers()
	for player, modeId in playerQueue do
		if not player.Parent or HubService.getPhase(player) ~= "hub" then
			if modeId then
				removeFromList(queues[modeId], player)
			end
			playerQueue[player] = nil
		end
	end
end

local function takePlayers(modeId, count)
	local taken = {}
	local list = queues[modeId]
	for i = #list, 1, -1 do
		if #taken >= count then
			break
		end
		local player = list[i]
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(taken, player)
			table.remove(list, i)
			playerQueue[player] = nil
		end
	end
	return taken
end

local function stopFfaFillTimer()
	ffaFillToken += 1
end

local function resetFfaFillState()
	stopFfaFillTimer()
	ffaReadyToStart = false
end

local function scheduleFfaFillTimer()
	resetFfaFillState()
	local token = ffaFillToken
	local timeout = MatchmakingConfig.MODES.ffa.fillTimeout

	task.delay(timeout, function()
		if token ~= ffaFillToken then
			return
		end
		ffaReadyToStart = true
		MatchmakingService.tryStartMatch()
	end)
end

local function maybeScheduleFfaFill()
	local ffaCount = getQueueCount("ffa")
	local config = MatchmakingConfig.MODES.ffa
	if ffaCount >= config.maxPlayers then
		ffaReadyToStart = true
		stopFfaFillTimer()
	elseif ffaCount >= config.minPlayers then
		scheduleFfaFillTimer()
	else
		resetFfaFillState()
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromList(queues[modeId], player)
	playerQueue[player] = nil

	if modeId == "ffa" and getQueueCount("ffa") < MatchmakingConfig.MODES.ffa.minPlayers then
		resetFfaFillState()
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates()
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if GameMatchState.isBusy() and playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	MatchmakingService.leaveQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if modeId == "ffa" then
		maybeScheduleFfaFill()
	end

	broadcastQueueUpdates()
	MatchmakingService.tryStartMatch()
end

function MatchmakingService.tryStartMatch()
	if GameMatchState.isBusy() then
		broadcastQueueUpdates()
		return
	end

	pruneInvalidPlayers()

	for _, modeId in { "training", "pvp", "ffa" } do
		local config = getModeConfig(modeId)
		local count = getQueueCount(modeId)
		if count < config.minPlayers then
			continue
		end

		local takeCount = math.min(count, config.maxPlayers)
		if modeId == "ffa" and count < config.maxPlayers and not ffaReadyToStart then
			continue
		end

		local players = takePlayers(modeId, takeCount)
		if #players < config.minPlayers then
			for _, player in players do
				table.insert(queues[modeId], player)
				playerQueue[player] = modeId
			end
			continue
		end

		if modeId == "ffa" then
			resetFfaFillState()
		end

		GameMatchState.setBusy(true)
		for _, player in players do
			HubService.leaveHubForArena(player)
			sendQueueUpdate(player)
		end
		broadcastQueueUpdates()
		MatchReady:Fire(players, modeId)
		return
	end

	broadcastQueueUpdates()
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	task.defer(function()
		maybeScheduleFfaFill()
		MatchmakingService.tryStartMatch()
	end)
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	ArenaFree = Bindables.ArenaFree

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
