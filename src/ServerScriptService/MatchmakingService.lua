local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillStartedAt = {}
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function queueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil
	if queueSize(modeId) == 0 then
		fillStartedAt[modeId] = nil
	end
end

local function buildUpdatePayload(modeId, status)
	local config = getModeConfig(modeId)
	local size = queueSize(modeId)
	local fillSecondsLeft

	if config.fillTimeout and fillStartedAt[modeId] then
		local elapsed = os.clock() - fillStartedAt[modeId]
		fillSecondsLeft = math.max(0, math.ceil(config.fillTimeout - elapsed))
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		queueSize = size,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status or "waiting",
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function broadcastQueue(modeId)
	local status = "waiting"
	if MatchStateService.isBusy() and queueSize(modeId) >= getModeConfig(modeId).minPlayers then
		status = "pending"
	end

	local payload = buildUpdatePayload(modeId, status)
	for _, player in queues[modeId] do
		if player.Parent and callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		if queueSize(modeId) > 0 then
			broadcastQueue(modeId)
		end
	end
end

local function takePlayers(modeId, count)
	local taken = {}
	for _ = 1, math.min(count, queueSize(modeId)) do
		local player = table.remove(queues[modeId], 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end

	if queueSize(modeId) == 0 then
		fillStartedAt[modeId] = nil
	end

	return taken
end

local function canStartMode(modeId)
	local config = getModeConfig(modeId)
	local size = queueSize(modeId)

	if size < config.minPlayers then
		return false
	end

	if size >= config.maxPlayers then
		return true
	end

	if config.fillTimeout and fillStartedAt[modeId] then
		local elapsed = os.clock() - fillStartedAt[modeId]
		if elapsed >= config.fillTimeout then
			return true
		end
	end

	if config.maxPlayers == config.minPlayers then
		return size >= config.minPlayers
	end

	return false
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		return false
	end

	if not canStartMode(modeId) then
		return false
	end

	local config = getModeConfig(modeId)
	local count = math.min(queueSize(modeId), config.maxPlayers)
	local players = takePlayers(modeId, count)

	if #players < config.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return false
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end

	broadcastAllQueues()
	return true
end

function MatchmakingService.configure(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if playerMode[player] == modeId then
		broadcastQueue(modeId)
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	local config = getModeConfig(modeId)
	if config.fillTimeout and queueSize(modeId) >= config.minPlayers and not fillStartedAt[modeId] then
		fillStartedAt[modeId] = os.clock()
	end

	broadcastQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	if callbacks.onQueueLeft then
		callbacks.onQueueLeft(player)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.tick()
	for modeId in MatchmakingConfig.MODES do
		if queueSize(modeId) > 0 then
			broadcastQueue(modeId)
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.processPending()
	for modeId in MatchmakingConfig.MODES do
		if tryStartMatch(modeId) then
			break
		end
	end
end

function MatchmakingService.handlePlayerRemoving(player)
	removeFromQueue(player)
end

MatchStateService.onArenaFree(function()
	MatchmakingService.processPending()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.handlePlayerRemoving(player)
end)

return MatchmakingService
