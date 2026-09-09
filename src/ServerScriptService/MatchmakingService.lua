local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatches = {}
local callbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {
		players = {},
		fillToken = 0,
	}
end

local function getQueuePlayers(modeId)
	local list = {}
	for _, player in queues[modeId].players do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function buildQueuePayload(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	local players = getQueuePlayers(modeId)
	local status = "waiting"

	if MatchStateService.isBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = player ~= nil and playerQueue[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId)
	for _, queuedPlayer in getQueuePlayers(modeId) do
		if callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(queuedPlayer, payload)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end
	queue.fillToken += 1
	broadcastQueue(modeId)
end

local function popMatchPlayers(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local players = getQueuePlayers(modeId)
	if #players < mode.minPlayers then
		return nil
	end

	local matchPlayers = {}
	for i = 1, math.min(#players, mode.maxPlayers) do
		table.insert(matchPlayers, players[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	return matchPlayers
end

local function notifyPlayer(player, payload)
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, payload)
	end
end

local function notifyPendingMatch(modeId, matchPlayers)
	local mode = MatchmakingConfig.getMode(modeId)
	for _, player in matchPlayers do
		notifyPlayer(player, {
			inQueue = true,
			status = "pending",
			modeId = modeId,
			modeLabel = mode.label,
			count = #matchPlayers,
			minPlayers = mode.minPlayers,
			maxPlayers = mode.maxPlayers,
		})
	end
end

local function deliverMatch(modeId, matchPlayers)
	if MatchStateService.isBusy() then
		table.insert(pendingMatches, { modeId = modeId, players = matchPlayers })
		notifyPendingMatch(modeId, matchPlayers)
		return
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(matchPlayers, modeId)
	end
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local players = getQueuePlayers(modeId)
	if #players < mode.minPlayers then
		return
	end

	if mode.maxPlayers and #players >= mode.maxPlayers then
		local matchPlayers = popMatchPlayers(modeId)
		if matchPlayers then
			deliverMatch(modeId, matchPlayers)
		end
		return
	end

	if mode.instant and #players >= mode.minPlayers then
		local matchPlayers = popMatchPlayers(modeId)
		if matchPlayers then
			deliverMatch(modeId, matchPlayers)
		end
		return
	end

	if mode.minPlayers == mode.maxPlayers and #players >= mode.minPlayers then
		local matchPlayers = popMatchPlayers(modeId)
		if matchPlayers then
			deliverMatch(modeId, matchPlayers)
		end
	end
end

local function scheduleFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode.fillTimeout then
		return
	end

	local queue = queues[modeId]
	queue.fillToken += 1
	local token = queue.fillToken

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end

		local players = getQueuePlayers(modeId)
		if #players >= mode.minPlayers and #players < mode.maxPlayers then
			local matchPlayers = popMatchPlayers(modeId)
			if matchPlayers then
				deliverMatch(modeId, matchPlayers)
			end
		end
	end)
end

function MatchmakingService.registerHandlers(handlers)
	callbacks = handlers or {}
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false
	end

	modeId = modeId or MatchmakingConfig.DEFAULT_MODE
	if not MatchmakingConfig.MODES[modeId] then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	removeFromQueue(player)

	playerQueue[player] = modeId
	table.insert(queues[modeId].players, player)
	broadcastQueue(modeId)

	local mode = MatchmakingConfig.getMode(modeId)
	if mode.fillTimeout and #getQueuePlayers(modeId) == mode.minPlayers then
		scheduleFillTimer(modeId)
	end

	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { inQueue = false, status = "idle" })
	end
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.onMatchEnded()
	if MatchStateService.isBusy() then
		return
	end

	if #pendingMatches > 0 then
		local nextMatch = table.remove(pendingMatches, 1)
		if nextMatch then
			local valid = {}
			for _, player in nextMatch.players do
				if player.Parent then
					table.insert(valid, player)
				end
			end
			if #valid >= MatchmakingConfig.getMode(nextMatch.modeId).minPlayers then
				deliverMatch(nextMatch.modeId, valid)
			end
		end
		return
	end

	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.cleanupPlayer(player)
	removeFromQueue(player)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.cleanupPlayer(player)
end)

MatchStateService.onArenaFreed(function()
	MatchmakingService.onMatchEnded()
end)

return MatchmakingService
