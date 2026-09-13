local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingStarts = {}
local remotes
local bindables
local started = false

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

local function getQueueList(modeId)
	local list = {}
	for player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	queues[modeId][player] = nil
	playerQueue[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local members = getQueueList(modeId)
	local names = {}
	for _, queuedPlayer in members do
		table.insert(names, queuedPlayer.DisplayName)
	end

	local status = "waiting"
	if GameMatchState.isArenaBusy() then
		status = "arena_busy"
	elseif #members >= mode.minPlayers and modeId == "ffa" and fillTimers[modeId] then
		status = "filling"
	elseif #members >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #members,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = true,
	}
end

local function broadcastQueue(modeId)
	for player in queues[modeId] do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function sendQueueCleared(player)
	remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function canStartMode(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local members = getQueueList(modeId)
	if #members < mode.minPlayers then
		return false
	end
	if modeId == "ffa" and fillTimers[modeId] then
		return false
	end
	return true
end

local function takePlayersForMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local members = getQueueList(modeId)
	table.sort(members, function(a, b)
		return a.UserId < b.UserId
	end)

	local matchPlayers = {}
	for i = 1, math.min(#members, mode.maxPlayers) do
		table.insert(matchPlayers, members[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	return matchPlayers
end

local function startMatch(modeId)
	if not canStartMode(modeId) or GameMatchState.isArenaBusy() then
		return false
	end

	local matchPlayers = takePlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return false
	end

	GameMatchState.setArenaBusy(true)

	for _, player in matchPlayers do
		remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			status = "starting",
			modeId = modeId,
			modeLabel = MatchmakingConfig.getMode(modeId).label,
		})
	end

	bindables.MatchReady:Fire({
		modeId = modeId,
		players = matchPlayers,
	})

	for otherModeId in queues do
		broadcastQueue(otherModeId)
	end

	return true
end

local function scheduleFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if mode.fillTimeout <= 0 or fillTimers[modeId] then
		return
	end

	local token = { cancelled = false }
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if token.cancelled or fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil

		if canStartMode(modeId) then
			if GameMatchState.isArenaBusy() then
				pendingStarts[modeId] = true
			else
				startMatch(modeId)
			end
		end
	end)
end

local function evaluateMode(modeId)
	if not canStartMode(modeId) then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if modeId == "ffa" then
		scheduleFillTimer(modeId)
		broadcastQueue(modeId)
		return
	end

	if GameMatchState.isArenaBusy() then
		pendingStarts[modeId] = true
		broadcastQueue(modeId)
		return
	end

	startMatch(modeId)
end

local function processPendingStarts()
	if GameMatchState.isArenaBusy() then
		return
	end

	local priority = { "training", "pvp", "ffa" }
	for _, modeId in priority do
		if pendingStarts[modeId] and canStartMode(modeId) then
			pendingStarts[modeId] = false
			if startMatch(modeId) then
				return
			end
		end
	end

	for modeId in MatchmakingConfig.MODES do
		if canStartMode(modeId) and not pendingStarts[modeId] then
			if modeId == "ffa" and not fillTimers[modeId] then
				scheduleFillTimer(modeId)
			elseif modeId ~= "ffa" then
				startMatch(modeId)
				return
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	if playerQueue[player] == modeId then
		remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		return
	end

	removeFromQueue(player)
	queues[modeId][player] = true
	playerQueue[player] = modeId

	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	broadcastQueue(modeId)
	evaluateMode(modeId)
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local modeId = MatchmakingConfig.getRecommendedMode(count)
	MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueCleared(player)
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	sendQueueCleared(player)
	broadcastQueue(modeId)
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaBusy(false)
	processPendingStarts()
end

function MatchmakingService.start(remoteFolder, bindableFolder)
	if started then
		return
	end
	started = true

	remotes = remoteFolder
	bindables = bindableFolder
	initQueues()

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
