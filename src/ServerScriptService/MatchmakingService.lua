local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local matchReady
local matchEnded

local queues = {}
local playerQueue = {}
local fillTokens = {}
local retryToken = 0

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local i = 1
	while i <= #queue do
		if not isValidPlayer(queue[i]) then
			playerQueue[queue[i]] = nil
			table.remove(queue, i)
		else
			i += 1
		end
	end
end

local function getQueueStatus(modeId)
	if MatchStateService.isBusy() then
		return "pending"
	end
	return "waiting"
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	pruneQueue(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = getQueueStatus(modeId),
		inQueue = position > 0,
	}
end

local function broadcastQueueUpdate(modeId)
	pruneQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if isValidPlayer(player) then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in pairs(queues) do
		broadcastQueueUpdate(modeId)
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if not silent then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		broadcastQueueUpdate(modeId)
	end

	local mode = MatchModes.get(modeId)
	if mode and #getQueue(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
	end
end

local function popMatchPlayers(modeId, count)
	pruneQueue(modeId)
	local queue = getQueue(modeId)
	local picked = {}
	local take = math.min(count, #queue)
	for _ = 1, take do
		local player = table.remove(queue, 1)
		if isValidPlayer(player) then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setBusy(true)
	for _, player in playerList do
		remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
	end
	broadcastAllQueues()

	matchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.maxPlayers == mode.minPlayers or #queue == mode.maxPlayers then
		clearFillTimer(modeId)
		local players = popMatchPlayers(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			launchMatch(modeId, players)
			broadcastQueueUpdate(modeId)
		end
		return
	end

	if mode.fillTimeout <= 0 then
		return
	end

	if #queue >= mode.minPlayers and not fillTokens[modeId .. "_active"] then
		fillTokens[modeId .. "_active"] = true
		fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
		local token = fillTokens[modeId]

		task.delay(mode.fillTimeout, function()
			fillTokens[modeId .. "_active"] = nil
			if token ~= fillTokens[modeId] then
				return
			end
			if MatchStateService.isBusy() then
				broadcastQueueUpdate(modeId)
				return
			end

			pruneQueue(modeId)
			local waiting = getQueue(modeId)
			if #waiting < mode.minPlayers then
				return
			end

			local players = popMatchPlayers(modeId, math.min(#waiting, mode.maxPlayers))
			if #players >= mode.minPlayers then
				launchMatch(modeId, players)
			end
			broadcastQueueUpdate(modeId)
		end)
	end
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player, false)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	removeFromQueue(player, true)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

local function onMatchEnded()
	MatchStateService.setBusy(false)
	retryToken += 1
	local token = retryToken

	task.delay(MatchmakingConfig.ARENA_BUSY_RETRY, function()
		if token ~= retryToken then
			return
		end
		for modeId in pairs(queues) do
			tryStartMatch(modeId)
		end
		broadcastAllQueues()
	end)
end

function MatchmakingService.init(remotesFolder, bindablesFolder)
	remotes = remotesFolder
	matchReady = bindablesFolder.MatchReady
	matchEnded = bindablesFolder.MatchEnded

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	matchEnded.Event:Connect(onMatchEnded)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
