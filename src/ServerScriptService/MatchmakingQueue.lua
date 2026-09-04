--[[
	Mode-based matchmaking queue for Nova Bladers.
	Players join a queue; when enough are waiting, a match starts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = select(1, RemotesSetup.ensure())

local MatchmakingQueue = {}

local queues = {}
local playerMode = {}
local onMatchReady = nil

local function initQueues()
	for modeId, cfg in HubConfig.QUEUE do
		queues[modeId] = {
			config = cfg,
			waiting = {},
			waitingSet = {},
		}
	end
end

initQueues()

local function getQueue(modeId)
	return queues[modeId]
end

local function buildStatus(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local queue = getQueue(modeId)
	if not queue then
		return { inQueue = false }
	end

	local position = 0
	for i, p in queue.waiting do
		if p == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = HubConfig.MODE_PADS[modeId] and HubConfig.MODE_PADS[modeId].label or modeId,
		position = position,
		count = #queue.waiting,
		required = queue.config.required,
		maxPlayers = queue.config.maxPlayers,
	}
end

local function broadcastQueueUpdate()
	for player, _ in playerMode do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildStatus(player))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	if queue then
		queue.waitingSet[player] = nil
		local nextWaiting = {}
		for _, p in queue.waiting do
			if p ~= player then
				table.insert(nextWaiting, p)
			end
		end
		queue.waiting = nextWaiting
	end

	playerMode[player] = nil
end

local function popPlayers(modeId)
	local queue = getQueue(modeId)
	if not queue then
		return {}
	end

	local cfg = queue.config
	local count = math.min(#queue.waiting, cfg.maxPlayers or #queue.waiting)
	if count < cfg.required then
		return {}
	end

	local matched = {}
	for i = 1, count do
		table.insert(matched, queue.waiting[i])
	end

	local remaining = {}
	for i = count + 1, #queue.waiting do
		table.insert(remaining, queue.waiting[i])
	end

	queue.waiting = remaining
	queue.waitingSet = {}
	for _, p in remaining do
		queue.waitingSet[p] = true
	end

	for _, p in matched do
		playerMode[p] = nil
	end

	return matched
end

local function tryStartMatch(modeId)
	local queue = getQueue(modeId)
	if not queue or #queue.waiting < queue.config.required then
		return
	end

	local matched = popPlayers(modeId)
	if #matched == 0 then
		return
	end

	broadcastQueueUpdate()

	if onMatchReady then
		onMatchReady(matched, modeId)
	end
end

function MatchmakingQueue.setOnMatchReady(callback)
	onMatchReady = callback
end

function MatchmakingQueue.join(player, modeId)
	if typeof(modeId) ~= "string" or not getQueue(modeId) then
		return false, "invalid_mode"
	end

	if playerMode[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildStatus(player))
		return true
	end

	removeFromQueue(player)
	playerMode[player] = modeId

	local queue = getQueue(modeId)
	table.insert(queue.waiting, player)
	queue.waitingSet[player] = true

	broadcastQueueUpdate()
	tryStartMatch(modeId)
	return true
end

function MatchmakingQueue.leave(player)
	if not playerMode[player] then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	removeFromQueue(player)
	broadcastQueueUpdate()
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingQueue.removePlayer(player)
	removeFromQueue(player)
end

function MatchmakingQueue.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingQueue.getStatus(player)
	return buildStatus(player)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.removePlayer(player)
	broadcastQueueUpdate()
end)

return MatchmakingQueue
