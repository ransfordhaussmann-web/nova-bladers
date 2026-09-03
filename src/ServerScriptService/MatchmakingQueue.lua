--[[
	MatchmakingQueue — per-mode queues (training / pvp / ffa).
	Starts a match when minimum players are met; FFA gathers briefly for more players.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes = RemotesSetup.ensure()

local MODE_CONFIG = {
	training = { min = 1, max = 1, label = "Training" },
	pvp = { min = 2, max = 2, label = "1v1 PvP" },
	ffa = { min = 3, max = HubConfig.QUEUE_FFA_MAX_PLAYERS, label = "FFA" },
}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerToMode = {}
local ffaGatherToken = 0
local onMatchReady = nil

local MatchmakingQueue = {}

local function isValidMode(modeId)
	return MODE_CONFIG[modeId] ~= nil
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function buildPayload(player)
	local modeId = playerToMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local cfg = MODE_CONFIG[modeId]
	local count = queueCount(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = cfg.label,
		count = count,
		needed = cfg.min,
		max = cfg.max,
		statusText = string.format("Warteschlange %s: %d/%d", cfg.label, count, cfg.min),
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildPayload(player))
	end
end

local function broadcastQueue(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendQueueUpdate(queuedPlayer)
	end
end

local function removeFromQueue(player)
	local modeId = playerToMode[player]
	if not modeId then
		return nil
	end

	playerToMode[player] = nil
	for index, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			table.remove(queues[modeId], index)
			break
		end
	end

	broadcastQueue(modeId)
	return modeId
end

local function takePlayers(modeId)
	local cfg = MODE_CONFIG[modeId]
	local queue = queues[modeId]
	if #queue < cfg.min then
		return nil
	end

	local players = {}
	local take = math.min(#queue, cfg.max)
	for _ = 1, take do
		local nextPlayer = queue[1]
		playerToMode[nextPlayer] = nil
		table.remove(queue, 1)
		table.insert(players, nextPlayer)
	end

	broadcastQueue(modeId)
	return players
end

local function fireMatchReady(players, modeId)
	if onMatchReady then
		onMatchReady(players, modeId)
	end
end

local function startImmediate(modeId)
	local players = takePlayers(modeId)
	if players then
		fireMatchReady(players, modeId)
	end

	if queueCount(modeId) >= MODE_CONFIG[modeId].min then
		MatchmakingQueue.tryStart(modeId)
	end
end

local function scheduleFfaGather()
	ffaGatherToken += 1
	local token = ffaGatherToken
	task.delay(HubConfig.QUEUE_FFA_GATHER_SECONDS, function()
		if token ~= ffaGatherToken then
			return
		end
		if queueCount("ffa") < MODE_CONFIG.ffa.min then
			return
		end
		startImmediate("ffa")
	end)
end

function MatchmakingQueue.registerCallback(callback)
	onMatchReady = callback
end

function MatchmakingQueue.tryStart(modeId)
	if not isValidMode(modeId) then
		return
	end

	local cfg = MODE_CONFIG[modeId]
	if queueCount(modeId) < cfg.min then
		return
	end

	if modeId == "ffa" then
		scheduleFfaGather()
		return
	end

	startImmediate(modeId)
end

function MatchmakingQueue.join(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end

	if not HubService.canJoinQueue(player) then
		return false, "busy"
	end

	if playerToMode[player] then
		if playerToMode[player] == modeId then
			sendQueueUpdate(player)
			return true
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerToMode[player] = modeId
	sendQueueUpdate(player)
	broadcastQueue(modeId)
	MatchmakingQueue.tryStart(modeId)
	return true
end

function MatchmakingQueue.leave(player)
	if not playerToMode[player] then
		return
	end

	removeFromQueue(player)
	sendQueueUpdate(player)
end

function MatchmakingQueue.isQueued(player)
	return playerToMode[player] ~= nil
end

function MatchmakingQueue.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingQueue.requeuePlayers(players, modeId)
	for _, player in players do
		if player.Parent and HubService.canJoinQueue(player) then
			MatchmakingQueue.join(player, modeId)
		end
	end
end

return MatchmakingQueue
