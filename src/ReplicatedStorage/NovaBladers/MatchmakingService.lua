local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}

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

local function removeFromQueue(player, modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end

	if #queue.players < (getModeConfig(modeId) and getModeConfig(modeId).minPlayers or 1) then
		queue.fillStartedAt = nil
	end

	if #queue.players == 0 then
		queues[modeId] = nil
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.getQueueSnapshot(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return nil
	end

	local queue = queues[modeId]
	local count = queue and #queue.players or 0
	return {
		modeId = modeId,
		label = config.label,
		count = count,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		players = queue and table.clone(queue.players) or {},
	}
end

function MatchmakingService.joinQueue(player, modeId)
	local config = getModeConfig(modeId)
	if not config then
		return false, "invalid_mode"
	end

	local currentMode = playerQueue[player]
	if currentMode == modeId then
		return true
	end

	if currentMode then
		MatchmakingService.leaveQueue(player)
	end

	local queue = ensureQueue(modeId)
	if #queue.players >= config.maxPlayers then
		return false, "queue_full"
	end

	for _, queuedPlayer in queue.players do
		if queuedPlayer == player then
			return true
		end
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId

	if #queue.players >= config.minPlayers and not queue.fillStartedAt and config.fillTimeout then
		queue.fillStartedAt = os.clock()
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	removeFromQueue(player, modeId)
	playerQueue[player] = nil
	return true
end

function MatchmakingService.removePlayer(player)
	return MatchmakingService.leaveQueue(player)
end

function MatchmakingService.isReadyToStart(modeId, arenaBusy)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not config or not queue or #queue.players == 0 then
		return false
	end

	if arenaBusy then
		return false
	end

	local count = #queue.players

	if config.id == "training" then
		return count >= 1
	end

	if count < config.minPlayers then
		return false
	end

	if count >= config.maxPlayers then
		return true
	end

	if config.fillTimeout and queue.fillStartedAt then
		return os.clock() - queue.fillStartedAt >= config.fillTimeout
	end

	return false
end

function MatchmakingService.popReadyPlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not config or not queue then
		return nil
	end

	local players = table.clone(queue.players)
	for _, player in players do
		playerQueue[player] = nil
	end

	queues[modeId] = nil
	return players, config.id
end

function MatchmakingService.getAllQueuedModes()
	local modes = {}
	for modeId in queues do
		table.insert(modes, modeId)
	end
	return modes
end

return MatchmakingService
