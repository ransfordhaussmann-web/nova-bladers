--[[
	MatchmakingService — per-mode queues (Training / 1v1 / FFA).
	Fires onMatchReady(modeId, playerList) when enough players are waiting.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local onMatchReadyCallback = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	return modeId
end

local function buildQueuePayload(modeId, queue)
	local config = getModeConfig(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		playersInQueue = #queue,
		playersNeeded = config.minPlayers,
	}
end

local function sendQueueState(player, payload)
	if player.Parent then
		Remotes.QueueState:FireClient(player, payload)
	end
end

local function broadcastQueueForMode(modeId)
	local queue = queues[modeId]
	local payload = buildQueuePayload(modeId, queue)
	for _, queuedPlayer in queue do
		sendQueueState(queuedPlayer, payload)
	end
end

local function tryStartMatches(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]

	while #queue >= config.minPlayers do
		local matchPlayers = {}
		local takeCount = math.min(config.maxPlayers, #queue)
		for _ = 1, takeCount do
			local nextPlayer = table.remove(queue, 1)
			playerQueue[nextPlayer] = nil
			table.insert(matchPlayers, nextPlayer)
		end

		for _, matchedPlayer in matchPlayers do
			sendQueueState(matchedPlayer, { inQueue = false })
		end

		if onMatchReadyCallback then
			onMatchReadyCallback(modeId, matchPlayers)
		end
	end

	broadcastQueueForMode(modeId)
end

function MatchmakingService.setOnMatchReady(callback)
	onMatchReadyCallback = callback
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end

	if playerQueue[player] == modeId then
		return true
	end

	local previousMode = removePlayerFromQueue(player)
	if previousMode then
		broadcastQueueForMode(previousMode)
	end

	playerQueue[player] = modeId
	table.insert(queues[modeId], player)
	broadcastQueueForMode(modeId)
	tryStartMatches(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removePlayerFromQueue(player)
	if not modeId then
		return false
	end

	sendQueueState(player, { inQueue = false })
	broadcastQueueForMode(modeId)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueCounts()
	local counts = {}
	for modeId, queue in queues do
		counts[modeId] = #queue
	end
	return counts
end

Players.PlayerRemoving:Connect(function(player)
	local modeId = removePlayerFromQueue(player)
	if modeId then
		broadcastQueueForMode(modeId)
	end
end)

return MatchmakingService
