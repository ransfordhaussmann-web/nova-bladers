--[[
	MatchmakingService — queue players by mode and start matches when ready.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local arenaBusy = false
local fillTimers = {}

local callbacks = {
	onQueueUpdate = nil,
	onMatchReady = nil,
}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function isPlayerQueued(player)
	return playerMode[player] ~= nil
end

local function buildUpdatePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	local position = table.find(queue, player) or 0
	local status = "waiting"
	if arenaBusy then
		status = "pending"
	end

	local fillRemaining
	local timer = fillTimers[modeId]
	if timer and timer.deadline then
		fillRemaining = math.max(0, math.ceil(timer.deadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeoutRemaining = fillRemaining,
	}
end

local function notifyPlayer(player)
	if callbacks.onQueueUpdate and player.Parent then
		callbacks.onQueueUpdate(player, buildUpdatePayload(player))
	end
end

local function notifyQueue(modeId)
	for _, player in queues[modeId] do
		notifyPlayer(player)
	end
end

local function notifyAllQueued()
	for player in playerMode do
		notifyPlayer(player)
	end
end

local function cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer and timer.thread then
		task.cancel(timer.thread)
	end
	fillTimers[modeId] = nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
	end
	playerMode[player] = nil

	if #queue < MatchmakingConfig.getMode(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	notifyPlayer(player)
	notifyQueue(modeId)
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end
	cancelFillTimer(modeId)
	notifyQueue(modeId)
	return taken
end

local function startMatch(modeId, players)
	if #players == 0 or arenaBusy then
		return
	end

	arenaBusy = true
	cancelFillTimer(modeId)
	notifyAllQueued()

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

local function tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	local count = #queue

	if count >= mode.maxPlayers then
		startMatch(modeId, takePlayers(modeId, mode.maxPlayers))
		return
	end

	if count < mode.minPlayers then
		cancelFillTimer(modeId)
		return
	end

	if mode.fillTimeout then
		local timer = fillTimers[modeId]
		if not timer then
			local deadline = os.clock() + mode.fillTimeout
			local thread = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				if arenaBusy then
					return
				end
				local current = queues[modeId]
				if #current >= mode.minPlayers then
					startMatch(modeId, takePlayers(modeId, #current))
				end
			end)
			fillTimers[modeId] = { deadline = deadline, thread = thread }
			notifyQueue(modeId)
		end
		return
	end

	startMatch(modeId, takePlayers(modeId, count))
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	notifyAllQueued()
	if not busy then
		for modeId in MatchmakingConfig.MODES do
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.isValidMode(modeId) then
		return false
	end
	if isPlayerQueued(player) then
		if playerMode[player] == modeId then
			notifyPlayer(player)
			return true
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	notifyPlayer(player)
	notifyQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not isPlayerQueued(player) then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.getQueueSize(modeId)
	return getQueueSize(modeId)
end

return MatchmakingService
