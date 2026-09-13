local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes, Bindables
local handlers = {}

local queues = {}
local playerQueue = {}
local ffaFillToken = 0
local ffaFillEndsAt = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

local function isValidMode(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if modeId == "ffa" and queueCount("ffa") < MatchmakingConfig.MODES.ffa.minPlayers then
		ffaFillToken += 1
		ffaFillEndsAt = nil
	end
end

local function getQueueStatus(modeId)
	if GameMatchState.isArenaBusy() then
		return "pending"
	end

	local config = getModeConfig(modeId)
	local count = queueCount(modeId)

	if modeId == "ffa" then
		if count >= config.maxPlayers then
			return "starting"
		end
		if count >= config.minPlayers and ffaFillEndsAt then
			return "fill"
		end
	end

	if config.instantStart and count >= config.minPlayers then
		return "starting"
	end
	if count >= config.minPlayers then
		return "starting"
	end

	return "waiting"
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local config = getModeConfig(modeId)
	local payload = {
		inQueue = true,
		mode = modeId,
		modeLabel = config.label,
		playersInQueue = queueCount(modeId),
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = getQueueStatus(modeId),
	}

	if modeId == "ffa" and ffaFillEndsAt then
		payload.fillSecondsLeft = math.max(0, math.ceil(ffaFillEndsAt - os.clock()))
	end

	return payload
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendQueueUpdate(queuedPlayer)
	end
end

local function broadcastAllQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			sendQueueUpdate(player)
		end
	end
end

local function takePlayersFromQueue(modeId, count)
	local taken = {}
	local queue = queues[modeId]
	for _ = 1, math.min(count, #queue) do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer then
			playerQueue[nextPlayer] = nil
			table.insert(taken, nextPlayer)
		end
	end
	return taken
end

local function leaveHubForMatch(player)
	if handlers.leaveHubForArena then
		handlers.leaveHubForArena(player)
	end
end

local function launchMatch(modeId, matchPlayers)
	if #matchPlayers == 0 then
		return
	end

	if modeId == "ffa" then
		ffaFillToken += 1
		ffaFillEndsAt = nil
	end

	for _, player in matchPlayers do
		leaveHubForMatch(player)
		sendQueueUpdate(player)
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = matchPlayers,
	})

	broadcastAllQueueUpdates()
end

local function tryStartMode(modeId)
	if GameMatchState.isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return false
	end

	local config = getModeConfig(modeId)
	local count = queueCount(modeId)

	if count < config.minPlayers then
		return false
	end

	local takeCount = math.min(count, config.maxPlayers)
	local matchPlayers = takePlayersFromQueue(modeId, takeCount)

	if modeId == "training" and #matchPlayers < 1 then
		return false
	elseif modeId == "pvp" and #matchPlayers < 2 then
		for _, player in matchPlayers do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		return false
	elseif modeId == "ffa" and #matchPlayers < config.minPlayers then
		for _, player in matchPlayers do
			table.insert(queues[modeId], 1, player)
			playerQueue[player] = modeId
		end
		return false
	end

	launchMatch(modeId, matchPlayers)
	return true
end

local function tryStartAllModes()
	for modeId in MatchmakingConfig.MODES do
		local config = getModeConfig(modeId)
		if config.instantStart then
			tryStartMode(modeId)
		elseif queueCount(modeId) >= config.maxPlayers then
			tryStartMode(modeId)
		end
	end

	for modeId in MatchmakingConfig.MODES do
		local config = getModeConfig(modeId)
		if not config.instantStart and queueCount(modeId) >= config.minPlayers then
			tryStartMode(modeId)
		end
	end
end

local function scheduleFfaFillTimer()
	local config = MatchmakingConfig.MODES.ffa
	if queueCount("ffa") < config.minPlayers then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	ffaFillEndsAt = os.clock() + config.fillTimeout
	broadcastQueueUpdates("ffa")

	task.delay(config.fillTimeout, function()
		if token ~= ffaFillToken then
			return
		end
		if queueCount("ffa") < config.minPlayers then
			ffaFillEndsAt = nil
			broadcastQueueUpdates("ffa")
			return
		end
		tryStartMode("ffa")
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not isValidMode(modeId) then
		if handlers.getQuickMatchMode then
			modeId = handlers.getQuickMatchMode()
		else
			modeId = "training"
		end
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)

	local config = getModeConfig(modeId)
	if config.instantStart then
		tryStartMode(modeId)
	elseif modeId == "ffa" then
		if queueCount("ffa") >= config.maxPlayers then
			tryStartMode("ffa")
		elseif queueCount("ffa") >= config.minPlayers and not ffaFillEndsAt then
			scheduleFfaFillTimer()
		elseif GameMatchState.isArenaBusy() then
			broadcastQueueUpdates("ffa")
		end
	elseif queueCount(modeId) >= config.minPlayers then
		tryStartMode(modeId)
	elseif GameMatchState.isArenaBusy() then
		broadcastQueueUpdates(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player)
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.onArenaFree()
	broadcastAllQueueUpdates()
	tryStartAllModes()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.start(newHandlers)
	handlers = newHandlers or {}
	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
