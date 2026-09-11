--[[
	MatchmakingService — queue logic for Training / PvP / FFA modes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local arenaBusy = false
local pendingMatch = nil
local fillTimers = {}
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local list = queues[modeId]
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	return modeId
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local config = getModeConfig(modeId)
	local count = queueCount(modeId)
	local status = "waiting"

	if arenaBusy and pendingMatch and pendingMatch.mode == modeId then
		status = "pending"
	elseif count >= config.minPlayers then
		status = arenaBusy and "pending" or "ready"
	end

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = config.label,
		count = count,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}
end

local function sendQueueUpdate(player)
	if callbacks.onQueueUpdate and player.Parent then
		callbacks.onQueueUpdate(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates()
	for player in playerQueue do
		sendQueueUpdate(player)
	end
end

local function snapshotPlayers(modeId)
	local snapshot = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(snapshot, player)
		end
	end
	return snapshot
end

local function clearQueue(modeId, matchedPlayers)
	local matchedSet = {}
	for _, player in matchedPlayers do
		matchedSet[player] = true
	end

	local remaining = {}
	for _, player in queues[modeId] do
		if matchedSet[player] then
			playerQueue[player] = nil
		else
			table.insert(remaining, player)
		end
	end
	queues[modeId] = remaining
end

local function startMatch(modeId, matchedPlayers)
	if #matchedPlayers == 0 then
		return
	end

	clearQueue(modeId, matchedPlayers)
	pendingMatch = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	arenaBusy = true
	broadcastQueueUpdates()

	HubService.onMatchStarting(matchedPlayers)

	if callbacks.onMatchReady then
		callbacks.onMatchReady({
			mode = modeId,
			players = matchedPlayers,
		})
	end
end

local function tryStartMatch(modeId)
	if arenaBusy then
		local config = getModeConfig(modeId)
		local count = queueCount(modeId)
		if count >= config.minPlayers then
			pendingMatch = {
				mode = modeId,
				players = snapshotPlayers(modeId),
			}
			broadcastQueueUpdates()
		end
		return
	end

	local config = getModeConfig(modeId)
	local count = queueCount(modeId)

	if count >= config.maxPlayers then
		local players = snapshotPlayers(modeId)
		local matched = {}
		for i = 1, config.maxPlayers do
			table.insert(matched, players[i])
		end
		startMatch(modeId, matched)
		return
	end

	if count >= config.minPlayers and config.fillTimeout <= 0 then
		startMatch(modeId, snapshotPlayers(modeId))
		return
	end

	if count >= config.minPlayers and config.fillTimeout > 0 and not fillTimers[modeId] then
		fillTimers[modeId] = task.delay(config.fillTimeout, function()
			fillTimers[modeId] = nil
			if arenaBusy then
				pendingMatch = {
					mode = modeId,
					players = snapshotPlayers(modeId),
				}
				broadcastQueueUpdates()
				return
			end

			local readyCount = queueCount(modeId)
			if readyCount >= config.minPlayers then
				startMatch(modeId, snapshotPlayers(modeId))
			end
		end)
	end
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return false, "invalid_mode"
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	sendQueueUpdate(player)
	broadcastQueueUpdates()
	HubService.onPlayerQueued(player, modeId)
	tryStartMatch(modeId)

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	removeFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdates()
	HubService.onPlayerLeftQueue(player)
	return true
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

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false

	if pendingMatch then
		local modeId = pendingMatch.mode
		local config = getModeConfig(modeId)
		local players = snapshotPlayers(modeId)
		local valid = {}
		for _, player in players do
			if player.Parent and playerQueue[player] == modeId then
				table.insert(valid, player)
			end
		end

		pendingMatch = nil

		if #valid >= config.minPlayers then
			startMatch(modeId, valid)
			return
		end
	end

	broadcastQueueUpdates()

	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	broadcastQueueUpdates()
end

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
end)

return MatchmakingService
