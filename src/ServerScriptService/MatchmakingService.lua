--[[
	MatchmakingService — queue state, fill timers, and MatchReady dispatch.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local arenaBusy = false
local fillTimers = {}
local onReadyCallback
local broadcastCallback

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function queueIndex(modeId, player)
	local list = queues[modeId]
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local list = queues[modeId]
	local index = queueIndex(modeId, player)
	if index then
		table.remove(list, index)
	end
	playerMode[player] = nil

	if fillTimers[modeId] then
		local config = getModeConfig(modeId)
		if #list < config.minPlayers then
			fillTimers[modeId] = nil
		end
	end

	return modeId
end

local function buildPlayerUpdate(player, modeId)
	local config = getModeConfig(modeId)
	local list = queues[modeId]
	local status = "waiting"

	if arenaBusy then
		status = "pending"
	elseif modeId == "ffa" and fillTimers[modeId] and #list >= config.minPlayers then
		status = "filling"
	end

	local payload = {
		inQueue = true,
		mode = modeId,
		modeLabel = config.label,
		position = queueIndex(modeId, player) or #list,
		total = #list,
		required = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}

	if status == "filling" and fillTimers[modeId] then
		payload.secondsLeft = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
	end

	return payload
end

function MatchmakingService.broadcastQueue(modeId)
	if not broadcastCallback then
		return
	end

	for _, player in queues[modeId] do
		if player.Parent then
			broadcastCallback(player, buildPlayerUpdate(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		MatchmakingService.broadcastQueue(modeId)
	end
end

local function popPlayers(modeId, count)
	local list = queues[modeId]
	local taken = {}
	local amount = math.min(count, #list)

	for _ = 1, amount do
		local player = table.remove(list, 1)
		if player and player.Parent then
			table.insert(taken, player)
			playerMode[player] = nil
		end
	end

	fillTimers[modeId] = nil
	return taken
end

local function tryStartMode(modeId)
	if arenaBusy then
		return false
	end

	local config = getModeConfig(modeId)
	local list = queues[modeId]
	if #list < config.minPlayers then
		return false
	end

	local shouldStart = false
	if #list >= config.maxPlayers then
		shouldStart = true
	elseif config.minPlayers == config.maxPlayers and #list >= config.minPlayers then
		shouldStart = true
	elseif modeId == "ffa" and fillTimers[modeId] and os.clock() >= fillTimers[modeId].endsAt then
		shouldStart = true
	elseif modeId == "training" and #list >= 1 then
		shouldStart = true
	end

	if not shouldStart then
		return false
	end

	local players = popPlayers(modeId, config.maxPlayers)
	if #players < config.minPlayers then
		for _, player in players do
			table.insert(list, player)
			playerMode[player] = modeId
		end
		return false
	end

	if onReadyCallback then
		onReadyCallback({
			mode = modeId,
			players = players,
		})
	end

	return true
end

function MatchmakingService.checkQueues()
	for modeId in queues do
		local config = getModeConfig(modeId)
		local list = queues[modeId]

		if config.fillTimeout and #list >= config.minPlayers and not fillTimers[modeId] then
			fillTimers[modeId] = {
				endsAt = os.clock() + config.fillTimeout,
			}
			MatchmakingService.broadcastQueue(modeId)
		end

		tryStartMode(modeId)
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	broadcastAllQueues()
	if not busy then
		MatchmakingService.checkQueues()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerMode[player] then
		return false, "already_queued"
	end
	if arenaBusy and modeId == "training" then
		-- Training can still queue but shows pending until arena is free.
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	MatchmakingService.broadcastQueue(modeId)
	MatchmakingService.checkQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId then
		MatchmakingService.broadcastQueue(modeId)
		if broadcastCallback then
			broadcastCallback(player, { inQueue = false })
		end
		return true
	end
	return false
end

function MatchmakingService.clearPlayer(player)
	local modeId = removeFromQueue(player)
	if modeId then
		MatchmakingService.broadcastQueue(modeId)
	end
end

function MatchmakingService.onMatchReady(callback)
	onReadyCallback = callback
end

function MatchmakingService.onQueueUpdate(callback)
	broadcastCallback = callback
end

return MatchmakingService
