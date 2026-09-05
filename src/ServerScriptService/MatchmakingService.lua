--[[
	Per-mode matchmaking queues: Training (1), 1v1 PvP (2), FFA (3+).
]]

local MatchmakingService = {}

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local QUEUE_MIN = {
	training = 1,
	pvp = 2,
	ffa = 3,
}

local FFA_MAX = 8

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local onMatchReady = nil

local function getQueueList(modeId)
	return queues[modeId]
end

local function removeFromList(list, player)
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, i)
			return true
		end
	end
	return false
end

function MatchmakingService.registerCallback(callback)
	onMatchReady = callback
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	removeFromList(getQueueList(modeId), player)
	playerQueue[player] = nil
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not QUEUE_MIN[modeId] then
		return false
	end

	MatchmakingService.leaveQueue(player)
	table.insert(getQueueList(modeId), player)
	playerQueue[player] = modeId
	MatchmakingService.tryStart(modeId)
	return true
end

function MatchmakingService.tryStart(modeId)
	local list = getQueueList(modeId)
	if not list then
		return
	end

	local minPlayers = QUEUE_MIN[modeId]
	while #list >= minPlayers do
		local matchPlayers = {}
		local takeCount = minPlayers

		if modeId == "ffa" then
			takeCount = math.min(#list, FFA_MAX)
		end

		for _ = 1, takeCount do
			local nextPlayer = table.remove(list, 1)
			if nextPlayer and nextPlayer.Parent then
				table.insert(matchPlayers, nextPlayer)
				playerQueue[nextPlayer] = nil
			end
		end

		if #matchPlayers < minPlayers then
			for _, queuedPlayer in matchPlayers do
				table.insert(list, 1, queuedPlayer)
				playerQueue[queuedPlayer] = modeId
			end
			break
		end

		if onMatchReady then
			onMatchReady(matchPlayers, modeId)
		end

		if modeId ~= "ffa" then
			break
		end
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getStatus(player)
	local modeId = playerQueue[player]
	if not modeId then
		return {
			inQueue = false,
			counts = MatchmakingService.getQueueCounts(),
		}
	end

	local list = getQueueList(modeId)
	local position = 0
	for index, queuedPlayer in list do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = MODE_LABELS[modeId] or modeId,
		queued = #list,
		required = QUEUE_MIN[modeId],
		position = position,
		counts = MatchmakingService.getQueueCounts(),
	}
end

function MatchmakingService.getQueueCounts()
	return {
		training = #queues.training,
		pvp = #queues.pvp,
		ffa = #queues.ffa,
	}
end

function MatchmakingService.requeuePlayers(players, modeId)
	if not QUEUE_MIN[modeId] then
		return
	end

	local list = getQueueList(modeId)
	for index = #players, 1, -1 do
		local queuedPlayer = players[index]
		if queuedPlayer and queuedPlayer.Parent then
			table.insert(list, 1, queuedPlayer)
			playerQueue[queuedPlayer] = modeId
		end
	end
end

function MatchmakingService.tryAllQueues()
	for modeId in pairs(QUEUE_MIN) do
		MatchmakingService.tryStart(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
