local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local arenaBusy = false
local fillTokens = {}
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillStartedAt = nil,
		}
	end
	return queues[modeId]
end

local function getPlayerStatus(modeId)
	if arenaBusy then
		return "pending"
	end

	local config = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players

	if modeId == "training" then
		return "ready"
	elseif modeId == "pvp" then
		return count >= config.minPlayers and "ready" or "waiting"
	elseif modeId == "ffa" then
		if count >= config.maxPlayers then
			return "ready"
		elseif count >= config.minPlayers then
			return queue.fillStartedAt and "filling" or "waiting"
		end
	end

	return "waiting"
end

local function buildQueuePayload(modeId, forPlayer)
	local config = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players
	local status = getPlayerStatus(modeId)
	local payload = {
		modeId = modeId,
		label = config.label,
		desc = config.desc,
		count = count,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		inQueue = forPlayer ~= nil and playerEntry[forPlayer] ~= nil,
	}

	if modeId == "ffa" and queue.fillStartedAt and config.fillTimeout then
		local elapsed = os.clock() - queue.fillStartedAt
		payload.fillRemaining = math.max(0, math.ceil(config.fillTimeout - elapsed))
	end

	return payload
end

local function broadcastQueueUpdate(modeId)
	if not callbacks.broadcast then
		return
	end

	for player, entry in playerEntry do
		if entry.modeId == modeId and player.Parent then
			callbacks.broadcast(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueueUpdate(modeId)
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local queue = queues[modeId]
	if queue then
		queue.fillStartedAt = nil
	end
end

local function popPlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player then
			playerEntry[player] = nil
			table.insert(picked, player)
		end
	end

	local config = getModeConfig(modeId)
	if config and #queue.players < config.minPlayers then
		clearFillTimer(modeId)
	end

	return picked
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	arenaBusy = true
	broadcastAllQueues()

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

function MatchmakingService.tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local queue = ensureQueue(modeId)
	local count = #queue.players

	if modeId == "training" and count >= 1 then
		launchMatch(modeId, popPlayers(modeId, 1))
	elseif modeId == "pvp" and count >= 2 then
		launchMatch(modeId, popPlayers(modeId, 2))
	elseif modeId == "ffa" and count >= config.maxPlayers then
		launchMatch(modeId, popPlayers(modeId, config.maxPlayers))
	end
end

local function scheduleFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config or not config.fillTimeout then
		return
	end

	local queue = ensureQueue(modeId)
	if queue.fillStartedAt then
		return
	end

	queue.fillStartedAt = os.clock()
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	broadcastQueueUpdate(modeId)

	task.delay(config.fillTimeout, function()
		if fillTokens[modeId] ~= token or arenaBusy then
			return
		end

		local currentQueue = queues[modeId]
		if not currentQueue or #currentQueue.players < config.minPlayers then
			clearFillTimer(modeId)
			broadcastQueueUpdate(modeId)
			return
		end

		local take = math.min(#currentQueue.players, config.maxPlayers)
		launchMatch(modeId, popPlayers(modeId, take))
	end)
end

function MatchmakingService.tryStartAll()
	for modeId in MatchmakingConfig.MODES do
		MatchmakingService.tryStartMatch(modeId)
		local config = getModeConfig(modeId)
		local queue = queues[modeId]
		if modeId == "ffa" and queue and config and #queue.players >= config.minPlayers then
			scheduleFillTimer(modeId)
		end
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	broadcastAllQueues()
	if not busy then
		MatchmakingService.tryStartAll()
	end
end

function MatchmakingService.isInQueue(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId or nil
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, i)
				break
			end
		end

		local config = getModeConfig(modeId)
		if config and #queue.players < config.minPlayers then
			clearFillTimer(modeId)
		end
	end

	playerEntry[player] = nil

	if callbacks.onQueueLeft then
		callbacks.onQueueLeft(player)
	end

	broadcastQueueUpdate(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	local config = getModeConfig(modeId)
	if not config then
		return false
	end

	MatchmakingService.leaveQueue(player)

	local queue = ensureQueue(modeId)
	table.insert(queue.players, player)
	playerEntry[player] = { modeId = modeId }

	broadcastQueueUpdate(modeId)
	MatchmakingService.tryStartMatch(modeId)

	if modeId == "ffa" and #queue.players >= config.minPlayers then
		scheduleFillTimer(modeId)
	end

	return true
end

function MatchmakingService.getQueueSnapshot(modeId, forPlayer)
	if not getModeConfig(modeId) then
		return nil
	end
	return buildQueuePayload(modeId, forPlayer)
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
