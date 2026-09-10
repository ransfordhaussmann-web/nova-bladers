local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local arenaBusy = false
local fillTimers = {}
local fillDeadline = {}
local onMatchReady = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
	fillDeadline[modeId] = nil
end

local function buildQueuePayload(modeId)
	local config = getModeConfig(modeId)
	local players = queues[modeId]
	local deadline = fillDeadline[modeId]
	local fillTimeLeft = nil
	if deadline then
		fillTimeLeft = math.max(0, math.ceil(deadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		count = #players,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		pending = arenaBusy,
		fillTimeLeft = fillTimeLeft,
	}
end

function MatchmakingService.setBroadcast(fn)
	MatchmakingService._broadcast = fn
end

local function broadcastMode(modeId)
	if MatchmakingService._broadcast then
		local payload = buildQueuePayload(modeId)
		for _, player in queues[modeId] do
			MatchmakingService._broadcast(player, payload)
		end
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.leaveQueue(player, silent)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queued in ipairs(queue) do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end
	playerMode[player] = nil

	if #queue < getModeConfig(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	if not silent then
		broadcastMode(modeId)
		if MatchmakingService._broadcast then
			MatchmakingService._broadcast(player, { count = 0 })
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return { ok = false, reason = "invalid_mode" }
	end

	MatchmakingService.leaveQueue(player, true)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	local payload = buildQueuePayload(modeId)
	broadcastMode(modeId)
	MatchmakingService._tryStartMatch(modeId)

	return {
		ok = true,
		status = arenaBusy and "pending" or "queued",
		queue = payload,
	}
end

function MatchmakingService._popPlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, config.maxPlayers)
	local players = {}

	for i = 1, count do
		table.insert(players, queue[i])
	end

	for _, player in players do
		MatchmakingService.leaveQueue(player, true)
	end

	clearFillTimer(modeId)
	return players
end

function MatchmakingService._tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = #queue

	if count < config.minPlayers then
		return
	end

	if modeId == "ffa" then
		if count >= config.maxPlayers then
			MatchmakingService._startMatch(modeId)
			return
		end

		if not fillTimers[modeId] then
			fillDeadline[modeId] = os.clock() + config.fillTimeout
			fillTimers[modeId] = task.delay(config.fillTimeout, function()
				fillTimers[modeId] = nil
				fillDeadline[modeId] = nil
				if #queues[modeId] >= config.minPlayers and not arenaBusy then
					MatchmakingService._startMatch(modeId)
				end
			end)
			broadcastMode(modeId)
		end
		return
	end

	MatchmakingService._startMatch(modeId)
end

function MatchmakingService._startMatch(modeId)
	if arenaBusy then
		return
	end

	local players = MatchmakingService._popPlayers(modeId)
	if #players == 0 then
		return
	end

	arenaBusy = true

	if onMatchReady then
		onMatchReady({
			modeId = modeId,
			players = players,
		})
	end
end

function MatchmakingService.setMatchReadyHandler(handler)
	onMatchReady = handler
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false

	for modeId in MatchmakingConfig.MODES do
		broadcastMode(modeId)
		MatchmakingService._tryStartMatch(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player, true)
end

return MatchmakingService
