local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromAllQueues(player)
	local previousMode = playerQueue[player]
	if not previousMode then
		return nil
	end

	local queue = queues[previousMode]
	if queue then
		for i, p in queue do
			if p == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil

	if fillTimers[previousMode] and #queue == 0 then
		fillTimers[previousMode] = nil
	end

	return previousMode
end

local function getQueueStatus(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return nil
	end

	local queue = ensureQueue(modeId)
	local count = #queue
	local pending = MatchStateService.isBusy()

	local status = "waiting"
	if pending then
		status = "pending"
	elseif modeId == "training" and count >= 1 then
		status = "ready"
	elseif modeId == "pvp" and count >= config.minPlayers then
		status = "ready"
	elseif modeId == "ffa" then
		if count >= config.maxPlayers then
			status = "ready"
		elseif count >= config.minPlayers and fillTimers[modeId] then
			local elapsed = os.clock() - fillTimers[modeId]
			if elapsed >= config.fillTimeout then
				status = "ready"
			else
				status = "filling"
			end
		end
	end

	return {
		modeId = modeId,
		label = config.label,
		count = count,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		pending = pending,
		fillRemaining = (status == "filling" and fillTimers[modeId])
			and math.max(0, math.ceil(config.fillTimeout - (os.clock() - fillTimers[modeId])))
			or nil,
	}
end

local function buildPlayerUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	return {
		inQueue = true,
		modeId = modeId,
		queue = getQueueStatus(modeId),
	}
end

local function notifyPlayer(player)
	if callbacks.onQueueUpdate and player.Parent then
		callbacks.onQueueUpdate(player, buildPlayerUpdate(player))
	end
end

local function notifyQueue(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		notifyPlayer(player)
	end
end

local function takePlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local taken = {}
	for i = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end

	fillTimers[modeId] = nil
	return taken
end

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	MatchStateService.setBusy(true)

	for _, player in players do
		notifyPlayer(player)
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady({
			mode = modeId,
			players = players,
		})
	end
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local queue = ensureQueue(modeId)
	local count = #queue

	if modeId == "training" and count >= 1 then
		startMatch(modeId, takePlayers(modeId, 1))
	elseif modeId == "pvp" and count >= 2 then
		startMatch(modeId, takePlayers(modeId, 2))
	elseif modeId == "ffa" then
		if count >= config.maxPlayers then
			startMatch(modeId, takePlayers(modeId, config.maxPlayers))
		elseif count >= config.minPlayers then
			if not fillTimers[modeId] then
				fillTimers[modeId] = os.clock()
				notifyQueue(modeId)
			elseif os.clock() - fillTimers[modeId] >= config.fillTimeout then
				startMatch(modeId, takePlayers(modeId, count))
			end
		end
	end
end

local function tryAllQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		return true
	end

	removeFromAllQueues(player)

	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	notifyQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromAllQueues(player)
	if modeId then
		notifyQueue(modeId)
		notifyPlayer(player)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromAllQueues(player)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(tryAllQueues)
end

function MatchmakingService.getQueueStatus(modeId)
	return getQueueStatus(modeId)
end

function MatchmakingService.processQueues()
	for modeId in MatchmakingConfig.MODES do
		if fillTimers[modeId] then
			notifyQueue(modeId)
		end
	end
	tryAllQueues()
end

return MatchmakingService
