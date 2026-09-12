local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTokens = {}
local onMatchReady
local onQueueUpdate

local function getMode(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function countValid(players)
	local n = 0
	for _, player in players do
		if player.Parent then
			n += 1
		end
	end
	return n
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	local cleaned = {}
	for _, player in queue do
		if player.Parent and playerQueue[player] and playerQueue[player].modeId == modeId then
			table.insert(cleaned, player)
		end
	end
	queues[modeId] = cleaned
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId] or {}
	pruneQueue(modeId)
	queue = queues[modeId] or {}

	local names = {}
	for _, player in queue do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		players = names,
		count = #names,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		fillTimeout = mode and mode.fillTimeout,
	}
end

local function broadcastQueue(modeId)
	if not onQueueUpdate then
		return
	end
	local payload = buildQueuePayload(modeId)
	local queue = queues[modeId] or {}
	for _, player in queue do
		if player.Parent then
			local state = playerQueue[player]
			onQueueUpdate(player, {
				inQueue = true,
				status = state and state.status or "waiting",
				queue = payload,
			})
		end
	end
end

local function clearPlayer(player)
	local state = playerQueue[player]
	if not state then
		return
	end
	local modeId = state.modeId
	playerQueue[player] = nil

	local queue = queues[modeId]
	if queue then
		for i, queued in queue do
			if queued == player then
				table.remove(queue, i)
				break
			end
		end
	end
	broadcastQueue(modeId)
end

local function popPlayers(modeId, count)
	pruneQueue(modeId)
	local queue = queues[modeId] or {}
	local picked = {}
	local remaining = {}

	for _, player in queue do
		if #picked < count and player.Parent then
			table.insert(picked, player)
			playerQueue[player] = nil
		else
			table.insert(remaining, player)
		end
	end

	queues[modeId] = remaining
	return picked
end

local function markQueuePending(modeId)
	local queue = queues[modeId] or {}
	for _, player in queue do
		local state = playerQueue[player]
		if state then
			state.status = "pending"
		end
	end
	broadcastQueue(modeId)
end

local function launchMatch(modeId, players)
	if fillTokens[modeId] then
		fillTokens[modeId] = nil
	end

	arenaBusy = true
	for _, player in players do
		playerQueue[player] = nil
	end
	broadcastQueue(modeId)

	if onMatchReady then
		onMatchReady(players, modeId)
	end
end

local function tryLaunchFromQueue(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local queue = queues[modeId] or {}
	local count = #queue
	if count < mode.minPlayers then
		return
	end

	if arenaBusy then
		markQueuePending(modeId)
		return
	end

	local take = math.min(count, mode.maxPlayers)
	local players = popPlayers(modeId, take)
	if #players >= mode.minPlayers then
		launchMatch(modeId, players)
	end
end

local function tryStartMode(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local queue = queues[modeId] or {}
	local count = #queue
	if count < mode.minPlayers then
		return
	end

	if mode.id == "ffa" and count >= mode.maxPlayers then
		if fillTokens[modeId] then
			fillTokens[modeId] = nil
		end
		tryLaunchFromQueue(modeId)
		return
	end

	if mode.id == "ffa" and mode.fillTimeout and count >= mode.minPlayers and count < mode.maxPlayers then
		if fillTokens[modeId] then
			if arenaBusy then
				markQueuePending(modeId)
			end
			return
		end

		fillTokens[modeId] = {}
		local token = fillTokens[modeId]
		broadcastQueue(modeId)

		task.delay(mode.fillTimeout, function()
			if fillTokens[modeId] ~= token then
				return
			end
			fillTokens[modeId] = nil
			tryLaunchFromQueue(modeId)
		end)
		return
	end

	tryLaunchFromQueue(modeId)
end

local function tryStartAll()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

function MatchmakingService.init(options)
	onMatchReady = options.onMatchReady
	onQueueUpdate = options.onQueueUpdate

	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode or not player.Parent then
		return
	end

	clearPlayer(player)

	playerQueue[player] = {
		modeId = modeId,
		status = arenaBusy and "pending" or "waiting",
	}

	local queue = queues[modeId]
	table.insert(queue, player)
	broadcastQueue(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	clearPlayer(player)
	if onQueueUpdate then
		onQueueUpdate(player, { inQueue = false })
	end
end

function MatchmakingService.getQueueState(player)
	local state = playerQueue[player]
	if not state then
		return { inQueue = false }
	end

	local mode = getMode(state.modeId)
	return {
		inQueue = true,
		status = state.status,
		queue = buildQueuePayload(state.modeId),
		modeLabel = mode and mode.label or state.modeId,
	}
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		for _, state in playerQueue do
			if state.status == "pending" then
				state.status = "waiting"
			end
		end
		tryStartAll()
	end
end

function MatchmakingService.onPlayerRemoving(player)
	clearPlayer(player)
end

return MatchmakingService
