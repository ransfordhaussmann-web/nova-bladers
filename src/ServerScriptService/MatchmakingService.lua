local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local pendingMatch = nil
local remotes = nil
local matchReadyEvent = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
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

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId, status, secondsLeft)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		mode = modeId,
		label = config.label,
		status = status,
		position = position,
		total = #queue,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		secondsLeft = secondsLeft,
	}
end

local function sendQueueUpdate(player, payload)
	if remotes and player.Parent then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	for _, player in queue do
		local status = "waiting"
		local secondsLeft = nil
		local timer = fillTimers[modeId]
		if timer and not timer.cancelled then
			status = "filling"
			secondsLeft = math.max(0, math.ceil(timer.endsAt - os.clock()))
		end
		sendQueueUpdate(player, buildQueuePayload(player, modeId, status, secondsLeft))
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerMode[player] = nil
		end
	end
	return picked
end

local function launchMatch(modeId, playerList)
	for _, player in playerList do
		HubService.enterArenaFromQueue(player)
		sendQueueUpdate(player, {
			mode = modeId,
			label = getModeConfig(modeId).label,
			status = "starting",
			position = 0,
			total = #playerList,
			minPlayers = getModeConfig(modeId).minPlayers,
			maxPlayers = getModeConfig(modeId).maxPlayers,
		})
	end

	if matchReadyEvent then
		matchReadyEvent:Fire(playerList)
	end
end

local function tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	if fillTimers[modeId] and not fillTimers[modeId].cancelled then
		return
	end

	local count = math.min(#queue, config.maxPlayers)
	local players = popPlayers(modeId, count)

	if #players < config.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	if MatchStateService.isBusy() then
		pendingMatch = {
			mode = modeId,
			players = players,
		}
		for _, player in players do
			sendQueueUpdate(player, buildQueuePayload(player, modeId, "pending", nil))
		end
		return
	end

	launchMatch(modeId, players)
end

local function startFillTimer(modeId)
	local config = getModeConfig(modeId)
	if config.fillTimeout <= 0 then
		tryStartMatch(modeId)
		return
	end

	if fillTimers[modeId] and not fillTimers[modeId].cancelled then
		return
	end

	local token = { cancelled = false }
	fillTimers[modeId] = {
		cancelled = false,
		endsAt = os.clock() + config.fillTimeout,
	}
	local timerRef = fillTimers[modeId]

	broadcastQueue(modeId)

	task.delay(config.fillTimeout, function()
		if timerRef.cancelled or fillTimers[modeId] ~= timerRef then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
		broadcastQueue(modeId)
	end)
end

local function evaluateMode(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]

	if #queue >= config.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if #queue >= config.minPlayers then
		if config.fillTimeout > 0 then
			startFillTimer(modeId)
		else
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.init(remotesFolder, bindablesFolder)
	remotes = remotesFolder
	matchReadyEvent = bindablesFolder.MatchReady
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if playerMode[player] then
		MatchmakingService.leaveQueue(player)
	end
	if HubService.getPhase(player) == "arena" then
		return false
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	HubService.enterQueue(player)

	broadcastQueue(modeId)
	evaluateMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	local modeId = playerMode[player]
	removeFromQueue(player)
	HubService.returnPlayerToHub(player)
	sendQueueUpdate(player, { status = "left" })
	broadcastQueue(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)

	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		launchMatch(match.mode, match.players)
	end
end

function MatchmakingService.onMatchStarted()
	MatchStateService.setBusy(true)
end

function MatchmakingService.getRecommendedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

Players.PlayerRemoving:Connect(function(player)
	if playerMode[player] then
		local modeId = playerMode[player]
		removeFromQueue(player)
		broadcastQueue(modeId)
		evaluateMode(modeId)
	end
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
		broadcastAllQueues()
	end
end)

local Remotes, Bindables = RemotesSetup.ensure()
MatchmakingService.init(Remotes, Bindables)

return MatchmakingService
