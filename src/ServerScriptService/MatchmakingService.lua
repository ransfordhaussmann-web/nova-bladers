local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerEntries = {}
local arenaBusy = false
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerEntries[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	if queue then
		for i, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, i)
				break
			end
		end

		if #queue.players < (getModeConfig(entry.modeId).minPlayers or 1) then
			queue.fillDeadline = nil
		end
	end

	playerEntries[player] = nil
end

local function getQueueStatus(modeId, queue)
	local config = getModeConfig(modeId)
	local count = #queue.players
	local status = "waiting"

	if arenaBusy then
		status = "pending"
	elseif config.id == "training" and count >= 1 then
		status = "ready"
	elseif config.id == "pvp" and count >= 2 then
		status = "ready"
	elseif config.id == "ffa" then
		if count >= config.maxPlayers then
			status = "ready"
		elseif count >= config.minPlayers and queue.fillDeadline and os.clock() >= queue.fillDeadline then
			status = "ready"
		end
	end

	return {
		modeId = modeId,
		label = config.label,
		count = count,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		fillSecondsLeft = queue.fillDeadline
			and math.max(0, math.ceil(queue.fillDeadline - os.clock()))
			or nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	local payload = getQueueStatus(modeId, queue)
	payload.players = {}
	for _, queuedPlayer in queue.players do
		if queuedPlayer.Parent then
			table.insert(payload.players, queuedPlayer.Name)
		end
	end

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(modeId, payload, queue.players)
	end
end

local function popMatchPlayers(modeId)
	local queue = ensureQueue(modeId)
	local config = getModeConfig(modeId)
	local count = math.min(#queue.players, config.maxPlayers)
	local matched = {}

	for i = 1, count do
		local player = queue.players[i]
		table.insert(matched, player)
		playerEntries[player] = nil
	end

	for i = 1, count do
		table.remove(queue.players, 1)
	end

	queue.fillDeadline = nil
	return matched
end

local function tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local queue = ensureQueue(modeId)
	local config = getModeConfig(modeId)
	local count = #queue.players

	if count < config.minPlayers then
		return
	end

	local ready = false
	if config.id == "training" or config.id == "pvp" then
		ready = count >= config.minPlayers
	elseif config.id == "ffa" then
		if count >= config.maxPlayers then
			ready = true
		elseif count >= config.minPlayers then
			if not queue.fillDeadline then
				queue.fillDeadline = os.clock() + config.fillTimeout
			end
			ready = os.clock() >= queue.fillDeadline
		end
	end

	if not ready then
		return
	end

	local players = popMatchPlayers(modeId)
	if #players == 0 then
		return
	end

	arenaBusy = true
	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, players)
	end
end

local MODE_PRIORITY = { "training", "pvp", "ffa" }

local function tryAllQueues()
	for _, modeId in MODE_PRIORITY do
		tryStartMatch(modeId)
		if arenaBusy then
			break
		end
	end
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		tryAllQueues()
	end
end

function MatchmakingService.getPlayerEntry(player)
	return playerEntries[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return false, "invalid_mode"
	end
	if arenaBusy and not playerEntries[player] then
		-- still allow joining; status becomes pending
	end
	if playerEntries[player] then
		if playerEntries[player].modeId == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	local queue = ensureQueue(modeId)
	if #queue.players >= getModeConfig(modeId).maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue.players, player)
	playerEntries[player] = { modeId = modeId }

	local config = getModeConfig(modeId)
	if config.id == "ffa" and #queue.players >= config.minPlayers and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + config.fillTimeout
	end

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntries[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	removeFromQueue(player)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.clearPlayer(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.tick()
	for modeId, queue in queues do
		if queue.fillDeadline and #queue.players >= getModeConfig(modeId).minPlayers then
			broadcastQueueUpdate(modeId)
			tryStartMatch(modeId)
		end
	end
end

return MatchmakingService
