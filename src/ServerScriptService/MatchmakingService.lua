local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTimers = {}
local callbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function isPlayerValid(player)
	return player and player.Parent ~= nil
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local i = 1
	while i <= #queue do
		if isPlayerValid(queue[i]) then
			i += 1
		else
			table.remove(queue, i)
		end
	end
end

local function removeFromAllQueues(player)
	for modeId, queue in queues do
		for i = #queue, 1, -1 do
			if queue[i] == player then
				table.remove(queue, i)
			end
		end
	end
	playerQueue[player] = nil
end

local function cancelFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

function MatchmakingService.setCallbacks(newCallbacks)
	callbacks = newCallbacks
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.getQueueSnapshot(modeId)
	pruneQueue(modeId)
	local mode = getMode(modeId)
	if not mode then
		return nil
	end

	local names = {}
	for _, player in queues[modeId] do
		table.insert(names, player.DisplayName)
	end

	return {
		modeId = modeId,
		label = mode.label,
		players = names,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = arenaBusy,
	}
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player].modeId
	removeFromAllQueues(player)
	cancelFillTimer(modeId)

	if callbacks.onQueueChanged then
		callbacks.onQueueChanged(player, modeId)
	end

	return true
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode or not isPlayerValid(player) then
		return false, "invalid"
	end

	if playerQueue[player] and playerQueue[player].modeId == modeId then
		return true, "already"
	end

	MatchmakingService.leaveQueue(player)
	pruneQueue(modeId)

	local queue = queues[modeId]
	if #queue >= mode.maxPlayers then
		return false, "full"
	end

	table.insert(queue, player)
	playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	if callbacks.onQueueChanged then
		callbacks.onQueueChanged(player, modeId)
	end

	MatchmakingService.tryStartMatch(modeId)
	return true, "joined"
end

function MatchmakingService.tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout and #queue < mode.maxPlayers then
		if not fillTimers[modeId] then
			local token = {}
			fillTimers[modeId] = token
			task.delay(mode.fillTimeout, function()
				if fillTimers[modeId] ~= token or arenaBusy then
					return
				end
				fillTimers[modeId] = nil
				MatchmakingService.startReadyMatch(modeId)
			end)
		end
		return
	end

	MatchmakingService.startReadyMatch(modeId)
end

function MatchmakingService.startReadyMatch(modeId)
	if arenaBusy then
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	cancelFillTimer(modeId)

	local matchPlayers = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromAllQueues(player)
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(matchPlayers, modeId)
	end
end

function MatchmakingService.onArenaFreed()
	arenaBusy = false
	for modeId in MatchmakingConfig.MODES do
		MatchmakingService.tryStartMatch(modeId)
	end
	if callbacks.onArenaFreed then
		callbacks.onArenaFreed()
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
