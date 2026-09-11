local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTokens = {}
local callbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function countQueue(modeId)
	local queue = queues[modeId]
	local count = 0
	for _, player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function buildQueueSnapshot(modeId)
	local config = getModeConfig(modeId)
	local entries = {}
	for index, player in queues[modeId] do
		if player.Parent then
			table.insert(entries, {
				userId = player.UserId,
				name = player.Name,
				position = index,
			})
		end
	end

	return {
		modeId = modeId,
		label = config.label,
		desc = config.desc,
		count = #entries,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		fillTimeout = config.fillTimeout,
		entries = entries,
		arenaBusy = MatchState.isBusy(),
		pending = MatchState.isBusy() and #entries >= config.minPlayers,
	}
end

local function notifyPlayer(player, payload)
	if callbacks.onQueueUpdate and player.Parent then
		callbacks.onQueueUpdate(player, payload)
	end
end

local function broadcastMode(modeId)
	local snapshot = buildQueueSnapshot(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			notifyPlayer(player, snapshot)
		end
	end
end

local function broadcastAll()
	for modeId in MatchmakingConfig.MODES do
		broadcastMode(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	broadcastMode(modeId)
	return modeId
end

local function takePlayers(modeId, amount)
	local queue = queues[modeId]
	local taken = {}
	local remaining = {}

	for _, player in queue do
		if player.Parent and #taken < amount then
			playerQueue[player] = nil
			table.insert(taken, player)
		else
			table.insert(remaining, player)
		end
	end

	queues[modeId] = remaining
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	broadcastMode(modeId)
	return taken
end

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, players)
	end
end

local function tryStartMatch(modeId)
	if MatchState.isBusy() then
		broadcastMode(modeId)
		return
	end

	local config = getModeConfig(modeId)
	local queueCount = countQueue(modeId)
	if queueCount < config.minPlayers then
		return
	end

	if modeId == "training" then
		startMatch(modeId, takePlayers(modeId, 1))
		return
	end

	if modeId == "pvp" and queueCount >= 2 then
		startMatch(modeId, takePlayers(modeId, 2))
		return
	end

	if modeId == "ffa" and queueCount >= config.minPlayers then
		if queueCount >= config.maxPlayers then
			startMatch(modeId, takePlayers(modeId, config.maxPlayers))
			return
		end

		local token = (fillTokens[modeId] or 0) + 1
		fillTokens[modeId] = token
		broadcastMode(modeId)

		task.delay(config.fillTimeout, function()
			if fillTokens[modeId] ~= token or MatchState.isBusy() then
				return
			end

			local currentCount = countQueue(modeId)
			if currentCount >= config.minPlayers then
				local takeCount = math.min(currentCount, config.maxPlayers)
				startMatch(modeId, takePlayers(modeId, takeCount))
			end
		end)
	end
end

function MatchmakingService.registerHandlers(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] == modeId then
		broadcastMode(modeId)
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastMode(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId and player.Parent then
		notifyPlayer(player, {
			modeId = modeId,
			left = true,
		})
	end
	return modeId ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	broadcastAll()
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.getActiveModeId()
	local Players = game:GetService("Players")
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
