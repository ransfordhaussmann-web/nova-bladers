local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local fillDeadlines = {}
local started = false

local Remotes
local Bindables
local HubService

local function getMode(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function clearFillTimer(modeId)
	fillDeadlines[modeId] = nil
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function getQueuePlayers(modeId)
	local mode = getMode(modeId)
	if not mode then
		return {}
	end

	local list = {}
	for _, player in queues[modeId] or {} do
		if isValidPlayer(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function buildUpdatePayload(modeId, player)
	local mode = getMode(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queued = getQueuePlayers(modeId)
	local names = {}
	for _, p in queued do
		table.insert(names, p.Name)
	end

	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		playerCount = #queued,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pendingArena = GameMatchState.isBusy(),
		fillTimeoutRemaining = nil,
	}

	local deadline = fillDeadlines[modeId]
	if deadline and mode.fillTimeout > 0 then
		payload.fillTimeoutRemaining = math.max(0, math.ceil(deadline - os.clock()))
	end

	return payload
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
end

local function broadcastQueueUpdate(modeId)
	for _, player in getQueuePlayers(modeId) do
		sendQueueUpdate(player)
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	if queue then
		for i = #queue, 1, -1 do
			if queue[i] == player then
				table.remove(queue, i)
			end
		end
	end

	if not silent then
		sendQueueUpdate(player)
		broadcastQueueUpdate(modeId)
	end

	local mode = getMode(modeId)
	if mode and #getQueuePlayers(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
	end
end

local function canStartMatch(modeId, afterFillTimeout)
	local mode = getMode(modeId)
	if not mode or GameMatchState.isBusy() then
		return false
	end

	local count = #getQueuePlayers(modeId)
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout <= 0 then
		return true
	end
	return afterFillTimeout == true
end

local function popMatchPlayers(modeId)
	local mode = getMode(modeId)
	local queued = getQueuePlayers(modeId)
	local take = math.min(#queued, mode.maxPlayers)
	local matchPlayers = {}

	for i = 1, take do
		local player = queued[i]
		table.insert(matchPlayers, player)
		removeFromQueue(player, true)
	end

	clearFillTimer(modeId)
	broadcastQueueUpdate(modeId)
	return matchPlayers
end

local function startMatch(modeId)
	if not canStartMatch(modeId) then
		return
	end

	local matchPlayers = popMatchPlayers(modeId)
	if #matchPlayers == 0 then
		return
	end

	for _, player in matchPlayers do
		if HubService.leaveForArena then
			HubService.leaveForArena(player)
		end
	end

	Bindables.MatchReady:Fire(matchPlayers, modeId)
end

local function tryStartMatch(modeId)
	if canStartMatch(modeId) then
		startMatch(modeId)
		return
	end

	local mode = getMode(modeId)
	local count = #getQueuePlayers(modeId)
	if not mode or count < mode.minPlayers then
		return
	end

	if mode.fillTimeout <= 0 then
		startMatch(modeId)
		return
	end

	if fillTimers[modeId] then
		broadcastQueueUpdate(modeId)
		return
	end

	fillDeadlines[modeId] = os.clock() + mode.fillTimeout
	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		fillDeadlines[modeId] = nil
		if canStartMatch(modeId, true) then
			startMatch(modeId)
		else
			broadcastQueueUpdate(modeId)
		end
	end)
	broadcastQueueUpdate(modeId)
end

local function joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	if playerQueue[player] then
		removeFromQueue(player, true)
	end

	if not queues[modeId] then
		queues[modeId] = {}
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)

	tryStartMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.joinRecommended(player)
	local count = #Players:GetPlayers()
	local modeId = MatchmakingConfig.getRecommendedModeId(count)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player, false)
end

function MatchmakingService.onArenaFree()
	for modeId in pairs(MatchmakingConfig.MODES) do
		tryStartMatch(modeId)
	end

	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			sendQueueUpdate(player)
		end
	end
end

function MatchmakingService.start(remotes, bindables, hubServiceRef)
	if started then
		return
	end
	started = true

	Remotes = remotes
	Bindables = bindables
	HubService = hubServiceRef

	for modeId in pairs(MatchmakingConfig.MODES) do
		queues[modeId] = {}
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			MatchmakingService.joinRecommended(player)
			return
		end
		if modeId == "quick" then
			MatchmakingService.joinRecommended(player)
			return
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
