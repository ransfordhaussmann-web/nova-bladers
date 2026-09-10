local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local ffaTimerToken = 0
local onUpdateCallback = nil
local onMatchReadyCallback = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = { players = {} }
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function cancelFFATimer()
	ffaTimerToken += 1
end

local function maybeStartFFATimer()
	local ffaQueue = queues.ffa
	if #ffaQueue.players < MatchmakingConfig.MODES.ffa.minPlayers then
		cancelFFATimer()
		return
	end
	if #ffaQueue.players >= MatchmakingConfig.MODES.ffa.maxPlayers then
		cancelFFATimer()
		return
	end

	ffaTimerToken += 1
	local token = ffaTimerToken
	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaTimerToken then
			return
		end
		MatchmakingService.tryStartMatch("ffa", true)
	end)
end

local function removePlayerFromQueues(player)
	local previousMode = playerMode[player]
	if not previousMode then
		return
	end

	local queue = queues[previousMode]
	for i = #queue.players, 1, -1 do
		if queue.players[i] == player then
			table.remove(queue.players, i)
		end
	end

	playerMode[player] = nil

	if previousMode == "ffa" and #queues.ffa.players < MatchmakingConfig.MODES.ffa.minPlayers then
		cancelFFATimer()
	end
end

local function getQueueStatus(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = #queue.players
	local needed = mode.minPlayers
	local status = "searching"

	if count >= needed then
		if MatchStateService.isArenaBusy() then
			status = "pending"
		else
			status = "ready"
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		playersInQueue = count,
		playersNeeded = needed,
		maxPlayers = mode.maxPlayers,
	}
end

local function broadcastQueueUpdates()
	if not onUpdateCallback then
		return
	end

	for modeId, queue in queues do
		for _, player in queue.players do
			if player.Parent then
				onUpdateCallback(player, getQueueStatus(player))
			end
		end
	end
end

local function canStartMatch(modeId, forceStart)
	local mode = getMode(modeId)
	local count = #queues[modeId].players

	if count < mode.minPlayers then
		return false
	end

	if modeId == "ffa" and not forceStart and count < mode.maxPlayers then
		return false
	end

	return true
end

local function takePlayers(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local takeCount = mode.maxPlayers

	if modeId == "ffa" then
		takeCount = math.min(#queue.players, mode.maxPlayers)
	end

	local taken = {}
	for _ = 1, takeCount do
		local player = table.remove(queue.players, 1)
		if player then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end

	return taken
end

function MatchmakingService.setCallbacks(callbacks)
	onUpdateCallback = callbacks.onQueueUpdate
	onMatchReadyCallback = callbacks.onMatchReady
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return false
	end

	if MatchStateService.isArenaBusy() and playerMode[player] == modeId then
		-- Allow re-join refresh while waiting for arena.
	elseif playerMode[player] then
		removePlayerFromQueues(player)
	end

	local queue = queues[modeId]
	for _, queued in queue.players do
		if queued == player then
			broadcastQueueUpdates()
			return true
		end
	end

	table.insert(queue.players, player)
	playerMode[player] = modeId

	if modeId == "ffa" then
		if #queue.players == MatchmakingConfig.MODES.ffa.minPlayers then
			maybeStartFFATimer()
		elseif #queue.players >= MatchmakingConfig.MODES.ffa.maxPlayers then
			cancelFFATimer()
			MatchmakingService.tryStartMatch("ffa")
		end
	else
		MatchmakingService.tryStartMatch(modeId)
	end

	broadcastQueueUpdates()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	removePlayerFromQueues(player)

	if onUpdateCallback and player.Parent then
		onUpdateCallback(player, { inQueue = false })
	end

	broadcastQueueUpdates()
end

function MatchmakingService.onPlayerRemoving(player)
	removePlayerFromQueues(player)
	broadcastQueueUpdates()
end

function MatchmakingService.tryStartMatch(modeId, forceStart)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates()
		return
	end

	if not canStartMatch(modeId, forceStart == true) then
		return
	end

	local players = takePlayers(modeId)
	if #players == 0 then
		return
	end

	if modeId == "ffa" then
		cancelFFATimer()
	end

	MatchStateService.setArenaBusy(true)
	broadcastQueueUpdates()

	if onMatchReadyCallback then
		onMatchReadyCallback({
			mode = modeId,
			players = players,
		})
	end
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	cancelFFATimer()

	for modeId in MatchmakingConfig.MODES do
		if modeId == "ffa" and #queues.ffa.players >= MatchmakingConfig.MODES.ffa.minPlayers then
			maybeStartFFATimer()
		end
		MatchmakingService.tryStartMatch(modeId)
	end

	broadcastQueueUpdates()
end

return MatchmakingService
