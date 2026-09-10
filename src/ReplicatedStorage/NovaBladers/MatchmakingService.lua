--[[
	MatchmakingService — queue state and match-ready logic (server-only usage).
]]

local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTimers = {}
local callbacks = {}

for modeId in pairs(MatchmakingConfig.MODES) do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function playerInQueue(player)
	return playerQueue[player] ~= nil
end

local function removeFromQueueList(player, modeId)
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end
end

local function cancelFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
	return token
end

local function buildQueueSnapshot(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		players = names,
		pending = arenaBusy,
	}
end

local function broadcastQueueUpdate(modeId)
	if not callbacks.onQueueUpdate then
		return
	end

	local snapshot = buildQueueSnapshot(modeId)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			callbacks.onQueueUpdate(queuedPlayer, snapshot)
		end
	end
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]

	while #queue > 0 and not queue[1].Parent do
		playerQueue[queue[1]] = nil
		table.remove(queue, 1)
	end

	if #queue < mode.minPlayers then
		return false
	end

	if arenaBusy then
		broadcastQueueUpdate(modeId)
		return false
	end

	local matchPlayers = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		local queuedPlayer = queue[i]
		if queuedPlayer.Parent then
			table.insert(matchPlayers, queuedPlayer)
		end
	end

	if #matchPlayers < mode.minPlayers then
		return false
	end

	cancelFillTimer(modeId)

	for _, matchedPlayer in matchPlayers do
		removeFromQueueList(matchedPlayer, modeId)
		playerQueue[matchedPlayer] = nil
	end

	arenaBusy = true

	if callbacks.onMatchReady then
		callbacks.onMatchReady(matchPlayers, modeId)
	end

	for modeKey in pairs(MatchmakingConfig.MODES) do
		broadcastQueueUpdate(modeKey)
	end

	return true
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId in pairs(MatchmakingConfig.MODES) do
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.getQueueSnapshot(modeId)
	if not isValidMode(modeId) then
		return nil
	end
	return buildQueueSnapshot(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	playerQueue[player] = nil
	removeFromQueueList(player, modeId)

	local mode = getMode(modeId)
	if #queues[modeId] < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)

	if callbacks.onPlayerLeftQueue then
		callbacks.onPlayerLeftQueue(player)
	end

	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if playerQueue[player] == modeId then
		return buildQueueSnapshot(modeId)
	end

	if playerInQueue(player) then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local snapshot = buildQueueSnapshot(modeId)
	broadcastQueueUpdate(modeId)

	local mode = getMode(modeId)
	if #queues[modeId] >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #queues[modeId] >= mode.minPlayers then
		if mode.fillTimeout then
			scheduleFillTimer(modeId)
		else
			tryStartMatch(modeId)
		end
	end

	return snapshot
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	for modeId in pairs(MatchmakingConfig.MODES) do
		local mode = getMode(modeId)
		if #queues[modeId] >= mode.minPlayers then
			if mode.fillTimeout and #queues[modeId] < mode.maxPlayers then
				scheduleFillTimer(modeId)
			else
				tryStartMatch(modeId)
			end
		else
			broadcastQueueUpdate(modeId)
		end
	end
end

return MatchmakingService
