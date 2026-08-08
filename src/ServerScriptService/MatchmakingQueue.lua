--[[
	MatchmakingQueue — per-mode player queues that start matches when filled.
]]

local MatchmakingConfig = require(game:GetService("ReplicatedStorage").NovaBladers.MatchmakingConfig)

local MatchmakingQueue = {}

local queues = {}
local playerQueue = {}
local callbacks = {}

for modeId in MatchmakingConfig.QUEUES do
	queues[modeId] = {}
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function buildSnapshotForPlayer(player)
	local modeId = playerQueue[player]
	local snapshot = {
		inQueue = modeId ~= nil,
		modeId = modeId,
		queues = {},
	}

	for id, queue in queues do
		local config = MatchmakingConfig.getQueue(id)
		snapshot.queues[id] = {
			count = #queue,
			minPlayers = config.minPlayers,
			maxPlayers = config.maxPlayers,
			label = config.label,
		}
	end

	return snapshot
end

local function broadcastUpdate()
	if not callbacks.onUpdate then
		return
	end
	for _, queue in queues do
		for _, player in queue do
			if player.Parent then
				callbacks.onUpdate(player, buildSnapshotForPlayer(player))
			end
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil
end

local function tryStartMatch(modeId)
	local config = MatchmakingConfig.getQueue(modeId)
	if not config then
		return
	end

	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	local matchPlayers = {}
	local take = math.min(#queue, config.maxPlayers)
	for i = 1, take do
		table.insert(matchPlayers, queue[1])
		playerQueue[queue[1]] = nil
		table.remove(queue, 1)
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(matchPlayers, modeId)
	end

	broadcastUpdate()
end

function MatchmakingQueue.register(newCallbacks)
	for key, fn in newCallbacks or {} do
		callbacks[key] = fn
	end
end

function MatchmakingQueue.join(player, modeId)
	if not MatchmakingConfig.isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] == modeId then
		return true
	end

	MatchmakingQueue.leave(player)
	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	broadcastUpdate()
	tryStartMatch(modeId)
	return true
end

function MatchmakingQueue.leave(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	broadcastUpdate()
end

function MatchmakingQueue.removePlayer(player)
	MatchmakingQueue.leave(player)
end

function MatchmakingQueue.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingQueue.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingQueue.getSnapshot(player)
	return buildSnapshotForPlayer(player)
end

return MatchmakingQueue
