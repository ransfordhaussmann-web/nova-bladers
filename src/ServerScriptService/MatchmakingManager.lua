--[[
	MatchmakingManager — mode-specific queues (Training / 1v1 / FFA).
	Starts a match when the minimum player count is reached.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local MatchmakingManager = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local gatherTokens = {}
local onMatchReadyCallback = nil
local canStartMatchCallback = function()
	return true
end
local remotes = nil

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local function getMinPlayers(modeId)
	return HubConfig.QUEUE_MIN_PLAYERS[modeId] or 1
end

local function getMaxPlayers(modeId)
	return HubConfig.QUEUE_MAX_PLAYERS[modeId] or 8
end

local function buildStatus(modeId)
	local count = #queues[modeId]
	local needed = getMinPlayers(modeId)
	return {
		mode = modeId,
		modeLabel = MODE_LABELS[modeId] or modeId,
		count = count,
		needed = needed,
		statusText = string.format("Warteschlange: %s (%d/%d)", MODE_LABELS[modeId] or modeId, count, needed),
	}
end

local function fireQueueUpdate(player, inQueue, modeId)
	if not remotes or not remotes.QueueUpdate then
		return
	end
	if inQueue and modeId then
		remotes.QueueUpdate:FireClient(player, {
			inQueue = true,
			queued = buildStatus(modeId),
		})
	else
		remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
		})
	end
end

local function broadcastQueue(modeId)
	local status = buildStatus(modeId)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			remotes.QueueUpdate:FireClient(queuedPlayer, {
				inQueue = true,
				queued = status,
			})
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	gatherTokens[modeId] = (gatherTokens[modeId] or 0) + 1

	local queue = queues[modeId]
	for index, queuedPlayer in ipairs(queue) do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerQueue[player] = nil
	fireQueueUpdate(player, false)
	broadcastQueue(modeId)
end

local function pullMatchPlayers(modeId)
	local queue = queues[modeId]
	local needed = getMinPlayers(modeId)
	if #queue < needed then
		return nil
	end

	local matchPlayers = {}
	local take = math.min(#queue, getMaxPlayers(modeId))
	for _ = 1, take do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerQueue[nextPlayer] = nil
			table.insert(matchPlayers, nextPlayer)
		end
	end

	broadcastQueue(modeId)

	if #matchPlayers < needed then
		for _, lostPlayer in matchPlayers do
			MatchmakingManager.joinQueue(lostPlayer, modeId)
		end
		return nil
	end

	return matchPlayers
end

local function tryStartMatch(modeId)
	local needed = getMinPlayers(modeId)
	if #queues[modeId] < needed then
		return
	end

	gatherTokens[modeId] = (gatherTokens[modeId] or 0) + 1
	local token = gatherTokens[modeId]
	local delay = (modeId == "training") and HubConfig.QUEUE_SOLO_DELAY or HubConfig.QUEUE_GATHER_DELAY

	task.delay(delay, function()
		if token ~= gatherTokens[modeId] then
			return
		end
		if #queues[modeId] < needed then
			return
		end
		if not canStartMatchCallback() then
			return
		end

		local matchPlayers = pullMatchPlayers(modeId)
		if not matchPlayers or not onMatchReadyCallback then
			return
		end

		for _, queuedPlayer in matchPlayers do
			fireQueueUpdate(queuedPlayer, false)
		end

		onMatchReadyCallback(matchPlayers, modeId)
		tryStartMatch(modeId)
	end)
end

function MatchmakingManager.init(remoteFolder)
	remotes = remoteFolder
end

function MatchmakingManager.onMatchReady(callback)
	onMatchReadyCallback = callback
end

function MatchmakingManager.setCanStartMatch(callback)
	canStartMatchCallback = callback
end

function MatchmakingManager.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingManager.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingManager.getStatus(modeId)
	return buildStatus(modeId)
end

function MatchmakingManager.joinQueue(player, modeId)
	if not queues[modeId] or not player.Parent then
		return false
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	fireQueueUpdate(player, true, modeId)
	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingManager.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingManager.cleanupPlayer(player)
	removeFromQueue(player)
end

function MatchmakingManager.requeuePlayers(players, modeId)
	if not queues[modeId] then
		return
	end

	for index = #players, 1, -1 do
		local queuedPlayer = players[index]
		if queuedPlayer.Parent and not playerQueue[queuedPlayer] then
			table.insert(queues[modeId], 1, queuedPlayer)
			playerQueue[queuedPlayer] = modeId
			fireQueueUpdate(queuedPlayer, true, modeId)
		end
	end

	broadcastQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingManager.processQueues()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingManager.cleanupPlayer(player)
end)

return MatchmakingManager
