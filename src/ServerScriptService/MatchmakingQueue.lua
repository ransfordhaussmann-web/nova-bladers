--[[
	MatchmakingQueue — mode-specific queues (Training / 1v1 / FFA).
	Starts matches when minimum player count is reached.
]]

local Players = game:GetService("Players")

local MatchmakingQueue = {}

local MODE_MIN = {
	training = 1,
	pvp = 2,
	ffa = 3,
}

local MODE_MAX = {
	training = 1,
	pvp = 2,
	ffa = 8,
}

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local onMatchReady
local onStatusUpdate

local function queueIndex(modeId, player)
	local q = queues[modeId]
	for i, p in q do
		if p == player then
			return i
		end
	end
	return nil
end

local function removeFromAllQueues(player)
	for modeId, q in queues do
		for i = #q, 1, -1 do
			if q[i] == player then
				table.remove(q, i)
			end
		end
	end
	playerMode[player] = nil
end

local function buildStatus(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local q = queues[modeId]
	local idx = queueIndex(modeId, player) or 1
	local minPlayers = MODE_MIN[modeId]
	local needed = math.max(0, minPlayers - #q)

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = MODE_LABELS[modeId],
		position = idx,
		totalInQueue = #q,
		needed = needed,
	}
end

local function broadcastStatus()
	if not onStatusUpdate then
		return
	end
	for player in playerMode do
		if player.Parent then
			onStatusUpdate(player, buildStatus(player))
		end
	end
end

local function popMatchPlayers(modeId)
	local q = queues[modeId]
	local minPlayers = MODE_MIN[modeId]
	local maxPlayers = MODE_MAX[modeId]

	if #q < minPlayers then
		return nil
	end

	local count = modeId == "ffa" and math.min(#q, maxPlayers) or minPlayers
	local players = {}
	for _ = 1, count do
		local player = table.remove(q, 1)
		if player then
			playerMode[player] = nil
			table.insert(players, player)
		end
	end

	return players
end

local function tryStartMatches()
	for modeId in queues do
		while true do
			local players = popMatchPlayers(modeId)
			if not players or #players == 0 then
				break
			end
			if onMatchReady then
				onMatchReady(players, modeId)
			end
		end
	end
	broadcastStatus()
end

function MatchmakingQueue.onMatchReady(callback)
	onMatchReady = callback
end

function MatchmakingQueue.onStatusUpdate(callback)
	onStatusUpdate = callback
end

function MatchmakingQueue.join(player, modeId)
	if not queues[modeId] then
		return false
	end
	if playerMode[player] == modeId then
		if onStatusUpdate then
			onStatusUpdate(player, buildStatus(player))
		end
		return true
	end

	removeFromAllQueues(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if onStatusUpdate then
		onStatusUpdate(player, buildStatus(player))
	end
	broadcastStatus()
	tryStartMatches()
	return true
end

function MatchmakingQueue.leave(player)
	if not playerMode[player] then
		return false
	end
	removeFromAllQueues(player)
	if onStatusUpdate then
		onStatusUpdate(player, buildStatus(player))
	end
	broadcastStatus()
	return true
end

function MatchmakingQueue.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingQueue.getMode(player)
	return playerMode[player]
end

function MatchmakingQueue.getStatus(player)
	return buildStatus(player)
end

function MatchmakingQueue.onPlayerRemoving(player)
	removeFromAllQueues(player)
	broadcastStatus()
end

return MatchmakingQueue
