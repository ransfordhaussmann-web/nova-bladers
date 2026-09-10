local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local onMatchReady = nil
local queueUpdateRemote = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {
			players = {},
			status = "waiting",
		}
	end
end

local function removePlayerFromList(list, player)
	for i = #list, 1, -1 do
		if list[i] == player then
			table.remove(list, i)
		end
	end
end

local function buildQueuePayload(modeId, player)
	local queue = queues[modeId]
	local mode = getModeConfig(modeId)
	if not queue or not mode then
		return { inQueue = false }
	end

	local position = 0
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		inQueue = position > 0,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		playersInQueue = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = queue.status,
	}
end

local function broadcastQueueUpdate(modeId)
	if not queueUpdateRemote then
		return
	end

	local queue = queues[modeId]
	for _, player in queue.players do
		if player.Parent then
			queueUpdateRemote:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function resetQueueState(modeId)
	local queue = queues[modeId]
	queue.status = "waiting"
	clearFillTimer(modeId)
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	resetQueueState(modeId)
	return taken
end

local function canStartMatch(modeId)
	local queue = queues[modeId]
	local mode = getModeConfig(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout and queue.status == "filling" then
		return true
	end
	if not mode.fillTimeout and count >= mode.minPlayers then
		return true
	end
	return false
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	HubService.enterArenaForMatch(players)

	if onMatchReady then
		onMatchReady(modeId, players)
	end
end

local function tryStartReadyMatch(modeId, takeCount)
	if MatchStateService.isArenaBusy() then
		queues[modeId].status = "pending"
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = getModeConfig(modeId)
	local count = math.min(takeCount, #queues[modeId].players, mode.maxPlayers)
	if count < mode.minPlayers then
		return
	end

	local players = takePlayers(modeId, count)
	launchMatch(modeId, players)
	broadcastQueueUpdate(modeId)
end

local function tryStartMatch(modeId)
	local queue = queues[modeId]
	local mode = getModeConfig(modeId)
	if not queue or not mode then
		return
	end

	local count = #queue.players
	if count < mode.minPlayers then
		return
	end

	if queue.status == "pending" and not MatchStateService.isArenaBusy() then
		tryStartReadyMatch(modeId, math.min(count, mode.maxPlayers))
		return
	end

	if count >= mode.maxPlayers then
		clearFillTimer(modeId)
		tryStartReadyMatch(modeId, mode.maxPlayers)
		return
	end

	if mode.fillTimeout then
		if queue.status == "waiting" then
			queue.status = "filling"
			broadcastQueueUpdate(modeId)
			clearFillTimer(modeId)
			fillTimers[modeId] = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				if #queues[modeId].players >= mode.minPlayers then
					tryStartReadyMatch(modeId, #queues[modeId].players)
				else
					resetQueueState(modeId)
					broadcastQueueUpdate(modeId)
				end
			end)
		elseif (queue.status == "filling" or queue.status == "pending") and canStartMatch(modeId) then
			tryStartReadyMatch(modeId, #queue.players)
		end
		return
	end

	tryStartReadyMatch(modeId, count)
end

function MatchmakingService.configure(options)
	onMatchReady = options.onMatchReady
	queueUpdateRemote = options.queueUpdateRemote
	initQueues()
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return false
	end

	if HubService.getPhase(player) == "arena" then
		return false
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removePlayerFromList(queues[modeId].players, player)
	playerQueue[player] = nil

	local queue = queues[modeId]
	if #queue.players < getModeConfig(modeId).minPlayers then
		resetQueueState(modeId)
	end

	broadcastQueueUpdate(modeId)

	if queueUpdateRemote and player.Parent then
		queueUpdateRemote:FireClient(player, { inQueue = false })
	end
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)

	for modeId, queue in queues do
		if queue.status == "pending" or (#queue.players >= getModeConfig(modeId).minPlayers) then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.getQuickJoinModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
