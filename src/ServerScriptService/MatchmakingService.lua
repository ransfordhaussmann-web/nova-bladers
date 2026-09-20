local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes = nil
local bindables = nil
local onMatchStart = nil

local queues = {}
local playerQueue = {}
local fillTimers = {}
local fillTokens = {}

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function countQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	local count = 0
	for player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function getQueuePlayers(modeId)
	local queue = queues[modeId]
	if not queue then
		return {}
	end
	local list = {}
	for player in queue do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function buildQueuePayload(player, modeId)
	local mode = getMode(modeId)
	local queueCount = countQueue(modeId)
	local pending = MatchStateService.isArenaBusy()
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		queueCount = queueCount,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		pending = pending,
		statusText = pending and MatchmakingConfig.STATUS_PENDING or MatchmakingConfig.STATUS_SEARCHING,
	}
end

local function sendQueueUpdate(player, modeId)
	if not remotes or not player.Parent then
		return
	end
	if modeId then
		remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	else
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function broadcastQueueUpdate(modeId)
	for player, queuedMode in playerQueue do
		if queuedMode == modeId and player.Parent then
			sendQueueUpdate(player, modeId)
		end
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		queue[player] = nil
	end
	playerQueue[player] = nil
	sendQueueUpdate(player, nil)
	broadcastQueueUpdate(modeId)

	local mode = getMode(modeId)
	if mode and countQueue(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
	end
end

local function popQueuePlayers(modeId, count)
	local queue = queues[modeId]
	if not queue then
		return {}
	end

	local list = getQueuePlayers(modeId)
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)

	local picked = {}
	for i = 1, math.min(count, #list) do
		table.insert(picked, list[i])
	end

	for _, player in picked do
		removeFromQueue(player)
	end

	return picked
end

local function notifyMatchReady(players, modeId)
	for _, player in players do
		sendQueueUpdate(player, modeId)
		if remotes then
			remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				modeId = modeId,
				statusText = MatchmakingConfig.STATUS_READY,
				pending = false,
			})
		end
	end

	if onMatchStart then
		onMatchStart(players, modeId)
	end

	if bindables and bindables.MatchReady then
		bindables.MatchReady:Fire(players, modeId)
	end
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		return
	end

	local queueCount = countQueue(modeId)
	if queueCount < mode.minPlayers then
		return
	end

	local takeCount = math.min(queueCount, mode.maxPlayers)
	local players = popQueuePlayers(modeId, takeCount)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	clearFillTimer(modeId)
	MatchStateService.setArenaBusy(true)
	notifyMatchReady(players, modeId)
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = true
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil

		if countQueue(modeId) >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			sendQueueUpdate(player, modeId)
			return true
		end
		removeFromQueue(player)
	end

	if not queues[modeId] then
		queues[modeId] = {}
	end

	queues[modeId][player] = true
	playerQueue[player] = modeId
	sendQueueUpdate(player, modeId)
	broadcastQueueUpdate(modeId)

	if mode.maxPlayers > 0 and countQueue(modeId) >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif countQueue(modeId) >= mode.minPlayers then
		if mode.fillTimeout <= 0 then
			tryStartMatch(modeId)
		else
			scheduleFillTimer(modeId)
			if mode.minPlayers == 1 then
				tryStartMatch(modeId)
			end
		end
	elseif MatchStateService.isArenaBusy() then
		-- Spieler wartet in Queue bis Arena frei ist
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player, nil)
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)

	task.delay(MatchmakingConfig.POST_MATCH_COOLDOWN, function()
		for modeId in queues do
			if countQueue(modeId) > 0 then
				local mode = getMode(modeId)
				if mode and countQueue(modeId) >= mode.minPlayers then
					if mode.fillTimeout > 0 and not fillTimers[modeId] then
						scheduleFillTimer(modeId)
					end
					tryStartMatch(modeId)
				end
			end
		end
	end)
end

function MatchmakingService.init(options)
	remotes = options.remotes
	bindables = options.bindables
	onMatchStart = options.onMatchStart

	for _, mode in MatchModes.all() do
		queues[mode.id] = queues[mode.id] or {}
	end

	if remotes then
		remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
			if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
				return
			end
			MatchmakingService.joinQueue(player, modeId)
		end)

		remotes.QueueLeave.OnServerEvent:Connect(function(player)
			MatchmakingService.leaveQueue(player)
		end)
	end

	if bindables and bindables.MatchEnded then
		bindables.MatchEnded.Event:Connect(function()
			MatchmakingService.onMatchEnded()
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)
end

return MatchmakingService
