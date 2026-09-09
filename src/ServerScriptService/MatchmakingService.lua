local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local queues = {}
local playerQueue = {}
local pendingMatches = {}
local fillTimers = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getPlayerNames(playerList)
	local names = {}
	for _, player in playerList do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end
	return names
end

local function buildQueuePayload(modeId, status)
	local config = getModeConfig(modeId)
	if not config then
		return nil
	end

	local queue = ensureQueue(modeId)
	local count = #queue
	local needed = config.maxPlayers

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		players = getPlayerNames(queue),
		count = count,
		needed = needed,
		minPlayers = config.minPlayers,
		status = status or "waiting",
	}
end

local function broadcastQueue(modeId, status)
	local payload = buildQueuePayload(modeId, status)
	if not payload then
		return
	end

	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = ensureQueue(modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	if #queue == 0 then
		clearFillTimer(modeId)
	end

	QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)
end

local function takePlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	clearFillTimer(modeId)
	return taken
end

local function startMatch(modeId, playerList)
	for _, player in playerList do
		HubService.prepareForMatch(player)
	end
	MatchReady:Fire(playerList, modeId)
end

local function processPending()
	if MatchStateService.isArenaBusy() or #pendingMatches == 0 then
		return
	end

	local nextMatch = table.remove(pendingMatches, 1)
	if nextMatch and #nextMatch.players > 0 then
		startMatch(nextMatch.modeId, nextMatch.players)
	end
end

local function queueMatchOrStart(modeId, playerList)
	if MatchStateService.isArenaBusy() then
		table.insert(pendingMatches, { modeId = modeId, players = playerList })
		for _, player in playerList do
			if player.Parent then
				local payload = buildQueuePayload(modeId, "pending")
				if payload then
					QueueUpdate:FireClient(player, payload)
				end
			end
		end
		return
	end

	startMatch(modeId, playerList)
end

local function canStartMode(modeId, forceFill)
	local config = getModeConfig(modeId)
	if not config then
		return false
	end

	local queue = ensureQueue(modeId)
	local count = #queue

	if modeId == "training" then
		return count >= 1
	elseif modeId == "pvp" then
		return count >= 2
	elseif modeId == "ffa" then
		if count >= config.maxPlayers then
			return true
		end
		if forceFill and count >= config.minPlayers then
			return true
		end
	end

	return false
end

local function tryStartMatch(modeId, forceFill)
	if not canStartMode(modeId, forceFill) then
		return
	end

	local config = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local takeCount = math.min(#queue, config.maxPlayers)

	if modeId == "pvp" then
		takeCount = 2
	elseif modeId == "training" then
		takeCount = 1
	end

	local players = takePlayers(modeId, takeCount)
	if #players == 0 then
		return
	end

	queueMatchOrStart(modeId, players)
end

local function startFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config or not config.fillTimeout then
		return
	end

	clearFillTimer(modeId)
	fillTimers[modeId] = task.delay(config.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId, true)
	end)
end

local function joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	broadcastQueue(modeId)

	local config = getModeConfig(modeId)
	if modeId == "ffa" and #queue == config.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId)
	end

	tryStartMatch(modeId)
end

local function leaveQueue(player)
	removeFromQueue(player)
end

QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	joinQueue(player, modeId)
end)

QueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
end)

MatchStateService.onArenaIdle(processPending)

local MatchmakingService = {
	joinQueue = joinQueue,
	leaveQueue = leaveQueue,
	getActiveModeId = function()
		local count = #Players:GetPlayers()
		if count >= 3 then
			return "ffa"
		elseif count == 2 then
			return "pvp"
		end
		return "training"
	end,
}

return MatchmakingService
