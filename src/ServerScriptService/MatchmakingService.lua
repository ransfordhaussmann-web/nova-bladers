local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)

local MatchmakingService = {}

local remotes
local bindables
local queues = {}
local playerQueue = {}
local pendingReady = nil

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function buildQueuePayload(modeId, queue)
	local mode = getMode(modeId)
	if not mode then
		return nil
	end

	local names = {}
	for _, player in queue.players do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end

	local status = "waiting"
	if queue.pending then
		status = "pending"
	elseif #queue.players >= mode.minPlayers and mode.fillTimeout > 0 and queue.fillDeadline then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		secondsLeft = queue.fillDeadline and math.max(0, math.ceil(queue.fillDeadline - os.clock())) or nil,
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	local payload = buildQueuePayload(modeId, queue)
	if not payload then
		return
	end

	for _, player in queue.players do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearFillTimer(queue)
	if queue.fillToken then
		queue.fillToken = nil
	end
	queue.fillDeadline = nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	playerQueue[player] = nil

	if not queue then
		return
	end

	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players == 0 then
		clearFillTimer(queue)
		queue.pending = false
		queues[modeId] = nil
	else
		broadcastQueue(modeId)
	end
end

local function collectReadyPlayers(modeId)
	local queue = queues[modeId]
	local mode = getMode(modeId)
	if not queue or not mode then
		return nil
	end

	local ready = {}
	for _, player in queue.players do
		if player.Parent and #ready < mode.maxPlayers then
			table.insert(ready, player)
		end
	end

	if #ready < mode.minPlayers then
		return nil
	end

	return ready
end

local function finalizeQueue(modeId)
	local ready = collectReadyPlayers(modeId)
	local mode = getMode(modeId)
	if not ready or not mode then
		return
	end

	queues[modeId] = nil
	for _, player in ready do
		playerQueue[player] = nil
	end

	if GameMatchState.isArenaBusy() then
		pendingReady = {
			players = ready,
			modeId = modeId,
		}
		for _, player in ready do
			if player.Parent then
				remotes.QueueUpdate:FireClient(player, {
					modeId = modeId,
					modeLabel = mode.label,
					players = {},
					count = #ready,
					minPlayers = mode.minPlayers,
					maxPlayers = mode.maxPlayers,
					status = "pending",
				})
			end
		end
		return
	end

	bindables.MatchReady:Fire(ready, modeId)
end

local function maybeStartFillTimer(modeId)
	local queue = queues[modeId]
	local mode = getMode(modeId)
	if not queue or not mode or mode.fillTimeout <= 0 then
		return
	end

	if #queue.players < mode.minPlayers then
		clearFillTimer(queue)
		return
	end

	if queue.fillDeadline then
		return
	end

	queue.fillToken = (queue.fillToken or 0) + 1
	local token = queue.fillToken
	queue.fillDeadline = os.clock() + mode.fillTimeout
	broadcastQueue(modeId)

	task.delay(mode.fillTimeout, function()
		local active = queues[modeId]
		if not active or active.fillToken ~= token then
			return
		end
		finalizeQueue(modeId)
	end)
end

local function tryStartQueue(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not mode or not queue then
		return
	end

	if mode.fillTimeout <= 0 and #queue.players >= mode.minPlayers then
		finalizeQueue(modeId)
		return
	end

	if #queue.players >= mode.maxPlayers then
		finalizeQueue(modeId)
		return
	end

	maybeStartFillTimer(modeId)
end

local function onArenaFree()
	if pendingReady and not GameMatchState.isArenaBusy() then
		local payload = pendingReady
		pendingReady = nil
		bindables.MatchReady:Fire(payload.players, payload.modeId)
		return
	end

	for modeId, queue in pairs(queues) do
		local mode = getMode(modeId)
		if mode and not queue.pending and #queue.players >= mode.minPlayers then
			tryStartQueue(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			pending = false,
		}
	end

	local queue = queues[modeId]
	if #queue.players >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start(remoteFolder, bindableFolder)
	remotes = remoteFolder
	bindables = bindableFolder

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
