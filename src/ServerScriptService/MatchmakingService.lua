local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local canStartMatch = function()
	return true
end
local onMatchReady

local function getRules(modeId)
	return HubConfig.QUEUE_RULES[modeId]
end

local function getQueuePosition(modeId, player)
	for index, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function buildQueuePayload(player, modeId)
	local rules = getRules(modeId)
	local queue = queues[modeId]
	return {
		status = "searching",
		modeId = modeId,
		modeLabel = rules.label,
		position = getQueuePosition(modeId, player),
		playersInQueue = #queue,
		playersNeeded = rules.minPlayers,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdate(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendQueueUpdate(queuedPlayer, buildQueuePayload(queuedPlayer, modeId))
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end
	broadcastQueueUpdate(modeId)
	sendQueueUpdate(player, { status = "idle" })
end

local function takePlayersFromQueue(modeId, count)
	local matched = {}
	local queue = queues[modeId]

	while #matched < count and #queue > 0 do
		local player = table.remove(queue, 1)
		if player.Parent then
			playerQueue[player] = nil
			table.insert(matched, player)
			sendQueueUpdate(player, {
				status = "matched",
				modeId = modeId,
				modeLabel = getRules(modeId).label,
			})
		end
	end

	broadcastQueueUpdate(modeId)
	return matched
end

local function tryFormMatch(modeId)
	if not canStartMatch() or not onMatchReady then
		return
	end

	local rules = getRules(modeId)
	if not rules or #queues[modeId] < rules.minPlayers then
		return
	end

	local matchSize = math.min(rules.maxPlayers, #queues[modeId])
	local matched = takePlayersFromQueue(modeId, matchSize)
	if #matched < rules.minPlayers then
		for _, player in matched do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
			sendQueueUpdate(player, buildQueuePayload(player, modeId))
		end
		broadcastQueueUpdate(modeId)
		return
	end

	onMatchReady(matched, modeId)
end

local function processQueues()
	for modeId in HubConfig.QUEUE_RULES do
		tryFormMatch(modeId)
	end
end

local MatchmakingService = {}

function MatchmakingService.configure(options)
	if options.canStartMatch then
		canStartMatch = options.canStartMatch
	end
	if options.onMatchReady then
		onMatchReady = options.onMatchReady
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not getRules(modeId) then
		return false
	end
	if not canStartMatch() and not playerQueue[player] then
		return false
	end

	clearPlayerFromQueues(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueUpdate(player, buildQueuePayload(player, modeId))
	broadcastQueueUpdate(modeId)
	tryFormMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	clearPlayerFromQueues(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.processQueues()
	processQueues()
end

Players.PlayerRemoving:Connect(function(player)
	clearPlayerFromQueues(player)
end)

return MatchmakingService
