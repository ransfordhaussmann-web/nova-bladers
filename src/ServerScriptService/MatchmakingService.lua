local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local matchReadyCallback = nil
local ffaGatherToken = 0

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	return modeId
end

local function countPlayers(queue)
	local total = 0
	for _, player in queue do
		if player.Parent then
			total += 1
		end
	end
	return total
end

local function pruneDisconnected(queue)
	for i = #queue, 1, -1 do
		if not queue[i].Parent then
			playerQueue[queue[i]] = nil
			table.remove(queue, i)
		end
	end
end

function MatchmakingService.getQueueSnapshot()
	local snapshot = {}
	for modeId, mode in MatchmakingConfig.MODES do
		pruneDisconnected(getQueue(modeId))
		snapshot[modeId] = {
			id = modeId,
			label = mode.label,
			count = countPlayers(getQueue(modeId)),
			required = mode.minPlayers,
			maxPlayers = mode.maxPlayers,
		}
	end
	return snapshot
end

function MatchmakingService.getPlayerState(player)
	local modeId = playerQueue[player]
	if not modeId then
		return {
			inQueue = false,
			modes = MatchmakingService.getQueueSnapshot(),
		}
	end

	local queue = getQueue(modeId)
	pruneDisconnected(queue)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local mode = MatchmakingConfig.getMode(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		playersInQueue = countPlayers(queue),
		requiredPlayers = mode.minPlayers,
		modes = MatchmakingService.getQueueSnapshot(),
	}
end

local function popPlayers(modeId, amount)
	local queue = getQueue(modeId)
	pruneDisconnected(queue)

	local picked = {}
	for _ = 1, math.min(amount, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end

	return picked
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	pruneDisconnected(queue)
	local readyCount = countPlayers(queue)
	if readyCount < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		ffaGatherToken += 1
		local token = ffaGatherToken
		task.delay(MatchmakingConfig.FFA_GATHER_SECONDS, function()
			if token ~= ffaGatherToken then
				return
			end
			local currentQueue = getQueue(modeId)
			pruneDisconnected(currentQueue)
			if countPlayers(currentQueue) < mode.minPlayers then
				return
			end
			local takeCount = math.min(countPlayers(currentQueue), mode.maxPlayers)
			local players = popPlayers(modeId, takeCount)
			if #players >= mode.minPlayers and matchReadyCallback then
				matchReadyCallback(modeId, players)
			end
		end)
		return
	end
	if #players >= mode.minPlayers and matchReadyCallback then
		matchReadyCallback(modeId, players)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.getMode(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	local mode = MatchmakingConfig.getMode(modeId)
	if modeId == "ffa" then
		if countPlayers(getQueue(modeId)) == mode.minPlayers then
			tryStartMatch(modeId)
		end
	else
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end
	removeFromQueue(player)
	if modeId == "ffa" then
		ffaGatherToken += 1
	end
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.onMatchReady(callback)
	matchReadyCallback = callback
end

function MatchmakingService.clearPlayer(player)
	removeFromQueue(player)
end

return MatchmakingService
