local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingManager = {}

local queues = {}
local playerQueue = {}
local waitTokens = {}
local onMatchReady = nil
local onQueueChanged = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
	waitTokens[modeId] = 0
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function copyPlayerList(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function buildQueuePayload(modeId, forPlayer)
	local config = getModeConfig(modeId)
	local players = copyPlayerList(modeId)
	local names = {}
	for _, player in players do
		table.insert(names, player.DisplayName)
	end

	local position = nil
	if forPlayer then
		for index, player in players do
			if player == forPlayer then
				position = index
				break
			end
		end
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		players = #players,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		queuedNames = names,
		position = position,
	}
end

local function broadcastQueueUpdate(modeId)
	if not onQueueChanged then
		return
	end
	for _, player in copyPlayerList(modeId) do
		onQueueChanged(player, buildQueuePayload(modeId, player))
	end
end

local function cancelWaitTimer(modeId)
	waitTokens[modeId] += 1
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerQueue[player] = nil
	broadcastQueueUpdate(modeId)

	local config = getModeConfig(modeId)
	if #queue < config.minPlayers then
		cancelWaitTimer(modeId)
	end

	return modeId
end

local function popReadyPlayers(modeId)
	local config = getModeConfig(modeId)
	local ready = {}
	local queue = queues[modeId]

	while #ready < config.maxPlayers and #queue > 0 do
		table.insert(ready, table.remove(queue, 1))
	end

	for _, player in ready do
		playerQueue[player] = nil
	end

	cancelWaitTimer(modeId)
	broadcastQueueUpdate(modeId)

	return ready
end

local function tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]

	if #queue < config.minPlayers then
		return
	end

	if #queue >= config.maxPlayers then
		local ready = popReadyPlayers(modeId)
		if onMatchReady and #ready > 0 then
			onMatchReady(ready, modeId)
		end
		return
	end

	if config.maxWait <= 0 then
		local ready = popReadyPlayers(modeId)
		if onMatchReady and #ready > 0 then
			onMatchReady(ready, modeId)
		end
		return
	end

	if waitTokens[modeId] == 0 or #queue == config.minPlayers then
		waitTokens[modeId] += 1
		local token = waitTokens[modeId]

		task.delay(config.maxWait, function()
			if token ~= waitTokens[modeId] then
				return
			end

			local current = copyPlayerList(modeId)
			if #current < config.minPlayers then
				return
			end

			local ready = popReadyPlayers(modeId)
			if onMatchReady and #ready > 0 then
				onMatchReady(ready, modeId)
			end
		end)
	end
end

function MatchmakingManager.setOnMatchReady(callback)
	onMatchReady = callback
end

function MatchmakingManager.setOnQueueChanged(callback)
	onQueueChanged = callback
end

function MatchmakingManager.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)

	if modeId == "training" then
		task.delay(MatchmakingConfig.GATHER_DELAY, function()
			if playerQueue[player] ~= modeId then
				return
			end
			local ready = popReadyPlayers(modeId)
			if onMatchReady and #ready > 0 then
				onMatchReady(ready, modeId)
			end
		end)
	else
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingManager.leaveQueue(player)
	local modeId = removeFromQueue(player)
	return modeId ~= nil
end

function MatchmakingManager.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingManager.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingManager.getQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end
	return buildQueuePayload(modeId, player)
end

function MatchmakingManager.clearPlayer(player)
	removeFromQueue(player)
end

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
end)

return MatchmakingManager
