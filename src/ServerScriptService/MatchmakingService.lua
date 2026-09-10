local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local arenaBusy = false
local fillTimers = {}

local callbacks = {
	onQueueUpdate = nil,
	onMatchReady = nil,
}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
	return token
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	return {
		modeId = modeId,
		label = mode.label,
		count = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
	}
end

local function getPlayerStatus(player, modeId)
	if arenaBusy then
		return "pending"
	end

	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = #queue

	if count >= mode.minPlayers then
		return "ready"
	end
	return "waiting"
end

local function broadcastQueueUpdate()
	if not callbacks.onQueueUpdate then
		return
	end

	local seen = {}
	for modeId, queue in queues do
		for _, player in queue do
			if player.Parent and not seen[player] then
				seen[player] = true
				local entry = playerEntry[player]
				callbacks.onQueueUpdate(player, {
					inQueue = true,
					modeId = entry.modeId,
					status = getPlayerStatus(player, entry.modeId),
					queue = buildQueuePayload(entry.modeId),
				})
			end
		end
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerEntry[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function tryStartMatch(modeId)
	if arenaBusy then
		broadcastQueueUpdate()
		return
	end

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout and #queue < mode.maxPlayers then
		if fillTimers[modeId] then
			return
		end

		local token = {}
		fillTimers[modeId] = token
		task.delay(mode.fillTimeout, function()
			if fillTimers[modeId] ~= token or arenaBusy then
				return
			end
			fillTimers[modeId] = nil

			local current = queues[modeId]
			if #current < mode.minPlayers then
				return
			end

			local players = popPlayers(modeId, math.min(#current, mode.maxPlayers))
			if #players >= mode.minPlayers and callbacks.onMatchReady then
				callbacks.onMatchReady(modeId, players)
			end
			broadcastQueueUpdate()
		end)
		broadcastQueueUpdate()
		return
	end

	clearFillTimer(modeId)
	local take = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, take)
	if #players >= mode.minPlayers and callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, players)
	end
	broadcastQueueUpdate()
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	broadcastQueueUpdate()

	if not arenaBusy then
		for modeId in queues do
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return false, "invalid_mode"
	end
	if playerEntry[player] then
		return false, "already_queued"
	end
	if arenaBusy and modeId == "training" then
		-- Training can still queue while arena is busy; it will start when free.
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = { modeId = modeId, joinedAt = os.clock() }

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, {
			inQueue = true,
			modeId = modeId,
			status = getPlayerStatus(player, modeId),
			queue = buildQueuePayload(modeId),
		})
	end

	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return false
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end
	playerEntry[player] = nil

	if #queue < getMode(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { inQueue = false })
	end
	broadcastQueueUpdate()
	return true
end

function MatchmakingService.removePlayer(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.getQueueState(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end
	return {
		inQueue = true,
		modeId = entry.modeId,
		status = getPlayerStatus(player, entry.modeId),
		queue = buildQueuePayload(entry.modeId),
	}
end

function MatchmakingService.setCallbacks(newCallbacks)
	callbacks = newCallbacks
end

return MatchmakingService
