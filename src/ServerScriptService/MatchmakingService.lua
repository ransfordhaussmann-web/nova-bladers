local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local onMatchStart = nil

for modeId, _ in MatchmakingConfig.MODES do
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

local function buildUpdatePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { status = "idle" }
	end

	local config = getModeConfig(modeId)
	local waiting = queueCount(modeId)
	local pending = MatchStateService.isArenaBusy()

	return {
		status = if pending then "pending" else "waiting",
		modeId = modeId,
		modeLabel = config.label,
		waiting = waiting,
		needed = config.maxPlayers,
		minPlayers = config.minPlayers,
		arenaBusy = pending,
	}
end

local function sendUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
	end
end

local function broadcastQueueUpdates(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendUpdate(queuedPlayer)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if queueCount(modeId) < getModeConfig(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdates(modeId)
	sendUpdate(player)
end

local function canStartMode(modeId)
	local config = getModeConfig(modeId)
	local count = queueCount(modeId)
	if count < config.minPlayers then
		return false
	end
	if config.maxPlayers and count >= config.maxPlayers then
		return true
	end
	if config.fillTimeout and fillTimers[modeId] then
		return true
	end
	if not config.fillTimeout and count >= config.minPlayers then
		return true
	end
	return false
end

local function popPlayersForMatch(modeId)
	local config = getModeConfig(modeId)
	local count = math.min(queueCount(modeId), config.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queues[modeId], 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(matchPlayers, player)
		end
	end

	clearFillTimer(modeId)
	return matchPlayers
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end
	if not canStartMode(modeId) then
		return
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers < getModeConfig(modeId).minPlayers then
		for _, player in matchPlayers do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		return
	end

	MatchStateService.setArenaBusy(true)
	clearFillTimer(modeId)

	for modeKey, _ in queues do
		broadcastQueueUpdates(modeKey)
	end

	if onMatchStart then
		onMatchStart(matchPlayers, modeId)
	end

	Bindables.MatchReady:Fire({
		players = matchPlayers,
		mode = modeId,
	})
end

local function scheduleFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config.fillTimeout or fillTimers[modeId] then
		return
	end
	if queueCount(modeId) < config.minPlayers then
		return
	end

	fillTimers[modeId] = task.delay(config.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function processQueues()
	for modeId, _ in MatchmakingConfig.MODES do
		if queueCount(modeId) > 0 then
			if canStartMode(modeId) and not MatchStateService.isArenaBusy() then
				tryStartMatch(modeId)
			else
				scheduleFillTimer(modeId)
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		return false, "already_queued"
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdates(modeId)
	sendUpdate(player)

	task.defer(processQueues)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	task.defer(processQueues)
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	for modeId, _ in MatchmakingConfig.MODES do
		broadcastQueueUpdates(modeId)
	end
	task.defer(processQueues)
end

function MatchmakingService.setMatchStartHandler(handler)
	onMatchStart = handler
end

function MatchmakingService.getSuggestedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
end)

return MatchmakingService
