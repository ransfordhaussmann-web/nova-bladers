local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {}
local playerToMode = {}
local arenaBusy = false
local onMatchReadyCallback = nil
local onQueueUpdateCallback = nil

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillTimer = nil,
		}
	end
	return queues[modeId]
end

local function cancelTimer(timerRef)
	if timerRef then
		task.cancel(timerRef)
	end
	return nil
end

local function clearQueueTimers(queue)
	queue.fillTimer = cancelTimer(queue.fillTimer)
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local status = "waiting"

	if arenaBusy then
		status = "pending"
	elseif modeId == "ffa" and #queue.players >= mode.minPlayers and queue.fillTimer then
		status = "filling"
	elseif modeId == "pvp" and #queue.players == 1 then
		status = "waiting"
	elseif #queue.players >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		label = mode.label,
		count = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdate(modeId)
	if onQueueUpdateCallback then
		onQueueUpdateCallback(modeId, buildQueuePayload(modeId))
	end
end

local function broadcastPlayerQueue(player)
	local modeId = playerToMode[player]
	if modeId then
		broadcastQueueUpdate(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerToMode[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerToMode[player] = nil

	if #queue.players == 0 then
		clearQueueTimers(queue)
	elseif modeId == "ffa" and #queue.players < getMode(modeId).minPlayers then
		queue.fillTimer = cancelTimer(queue.fillTimer)
	end

	broadcastQueueUpdate(modeId)
end

local function popQueuePlayers(modeId)
	local queue = ensureQueue(modeId)
	local players = table.clone(queue.players)
	queue.players = {}
	clearQueueTimers(queue)

	for _, player in players do
		playerToMode[player] = nil
	end

	broadcastQueueUpdate(modeId)
	return players
end

local function startMatch(modeId)
	if arenaBusy then
		return
	end

	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	if #queue.players < mode.minPlayers then
		return
	end

	arenaBusy = true
	local players = popQueuePlayers(modeId)

	if onMatchReadyCallback then
		onMatchReadyCallback(players, modeId)
	end
end

local function evaluateQueue(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	local count = #queue.players

	if arenaBusy then
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.instant and count >= mode.minPlayers then
		startMatch(modeId)
		return
	end

	if modeId == "pvp" and count >= mode.maxPlayers then
		startMatch(modeId)
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			queue.fillTimer = cancelTimer(queue.fillTimer)
			startMatch(modeId)
		elseif count >= mode.minPlayers and not queue.fillTimer then
			queue.fillTimer = task.delay(mode.fillTimeout, function()
				queue.fillTimer = nil
				if #queue.players >= mode.minPlayers and not arenaBusy then
					startMatch(modeId)
				end
			end)
		elseif count < mode.minPlayers then
			queue.fillTimer = cancelTimer(queue.fillTimer)
		end
	end
end

function MatchmakingService.setCallbacks(callbacks)
	onMatchReadyCallback = callbacks.onMatchReady
	onQueueUpdateCallback = callbacks.onQueueUpdate
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId in MatchmakingConfig.MODES do
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerToMode[player]
end

function MatchmakingService.getQueuePayload(modeId)
	return buildQueuePayload(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	local mode = getMode(modeId)
	if not mode then
		return false
	end

	removeFromQueue(player)

	local queue = ensureQueue(modeId)
	if #queue.players >= mode.maxPlayers then
		return false
	end

	table.insert(queue.players, player)
	playerToMode[player] = modeId
	broadcastQueueUpdate(modeId)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.removePlayer(player)
	removeFromQueue(player)
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	for modeId in MatchmakingConfig.MODES do
		evaluateQueue(modeId)
	end
end

return MatchmakingService
