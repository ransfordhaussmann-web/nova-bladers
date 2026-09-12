local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTokens = {}
local arenaBusy = false
local onMatchReady = nil
local onQueueUpdate = nil

local function getQueueList(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local list = queues[entry.modeId]
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, i)
			break
		end
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local list = getQueueList(modeId)
	return {
		modeId = modeId,
		label = mode.label,
		count = #list,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
	}
end

local function broadcastQueueUpdate(modeId)
	if not onQueueUpdate then
		return
	end

	local payload = buildQueuePayload(modeId)
	for _, queuedPlayer in getQueueList(modeId) do
		if queuedPlayer.Parent then
			local status = arenaBusy and "pending" or "waiting"
			onQueueUpdate(queuedPlayer, {
				status = status,
				queue = payload,
			})
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function takePlayers(modeId, count)
	local list = getQueueList(modeId)
	local taken = {}
	for i = 1, math.min(count, #list) do
		local player = list[1]
		table.remove(list, 1)
		playerQueue[player] = nil
		table.insert(taken, player)
	end
	return taken
end

local function tryStartMatch(modeId)
	if arenaBusy then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local list = getQueueList(modeId)
	if #list < mode.minPlayers then
		return
	end

	if mode.fillTimeout <= 0 or #list >= mode.maxPlayers then
		cancelFillTimer(modeId)
		fillTokens[modeId .. "_active"] = nil
		local players = takePlayers(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers and onMatchReady then
			arenaBusy = true
			onMatchReady(modeId, players)
		end
		return
	end

	if not fillTokens[modeId .. "_active"] then
		fillTokens[modeId .. "_active"] = true
		local token = (fillTokens[modeId] or 0) + 1
		fillTokens[modeId] = token

		task.delay(mode.fillTimeout, function()
			fillTokens[modeId .. "_active"] = nil
			if token ~= fillTokens[modeId] or arenaBusy then
				return
			end

			local current = getQueueList(modeId)
			if #current < mode.minPlayers then
				return
			end

			local players = takePlayers(modeId, math.min(#current, mode.maxPlayers))
			if #players >= mode.minPlayers and onMatchReady then
				arenaBusy = true
				onMatchReady(modeId, players)
			end
		end)
	end
end

function MatchmakingService.init(callbacks)
	onMatchReady = callbacks.onMatchReady
	onQueueUpdate = callbacks.onQueueUpdate
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId in queues do
		broadcastQueueUpdate(modeId)
		if not busy then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.getMode(modeId) then
		return false, "invalid_mode"
	end

	removeFromQueue(player)
	table.insert(getQueueList(modeId), player)
	playerQueue[player] = { modeId = modeId }

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return false
	end

	local modeId = entry.modeId
	removeFromQueue(player)
	cancelFillTimer(modeId)
	fillTokens[modeId .. "_active"] = nil
	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.removePlayer(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
