local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local started = false
local onArenaFree = nil

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {
			players = {},
			fillToken = 0,
			fillDeadline = nil,
		}
	end
end

local function playerInList(list, player)
	for i, p in list do
		if p == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	local index = playerInList(queue.players, player)
	if index then
		table.remove(queue.players, index)
	end
	playerQueue[player] = nil

	if #queue.players < MatchmakingConfig.MODES[modeId].minPlayers then
		queue.fillToken += 1
		queue.fillDeadline = nil
	end

	return modeId
end

local function buildPlayerPayload(player, modeId)
	local queue = queues[modeId]
	local position = playerInList(queue.players, player) or 0
	local mode = MatchmakingConfig.MODES[modeId]
	local status = MatchState.QueueStatus.Waiting

	if arenaBusy then
		status = MatchState.QueueStatus.Pending
	elseif #queue.players >= mode.minPlayers then
		status = MatchState.QueueStatus.Starting
	end

	local fillRemaining = nil
	if queue.fillDeadline then
		fillRemaining = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		mode = modeId,
		modeLabel = mode.label,
		position = position,
		total = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillRemaining = fillRemaining,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId or not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildPlayerPayload(player, modeId))
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue.players do
		sendQueueUpdate(player)
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerQueue[player] = nil
		end
	end
	queue.fillToken += 1
	queue.fillDeadline = nil
	return picked
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	local queue = queues[modeId]
	if not mode or #queue.players < mode.minPlayers then
		return
	end

	if arenaBusy then
		broadcastQueueUpdate(modeId)
		return
	end

	local count = math.min(#queue.players, mode.maxPlayers)
	local players = popPlayers(modeId, count)
	if #players < mode.minPlayers then
		return
	end

	arenaBusy = true
	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, {
			mode = modeId,
			modeLabel = mode.label,
			status = MatchState.QueueStatus.Starting,
			total = #players,
		})
	end

	Bindables.MatchReady:Fire(players, modeId)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	local queue = queues[modeId]
	if mode.fillTimeout <= 0 or #queue.players < mode.minPlayers then
		return
	end

	queue.fillToken += 1
	local token = queue.fillToken
	queue.fillDeadline = os.clock() + mode.fillTimeout
	broadcastQueueUpdate(modeId)

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		if #queue.players >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

local function onQueueChanged(modeId)
	broadcastQueueUpdate(modeId)

	local mode = MatchmakingConfig.MODES[modeId]
	local queue = queues[modeId]
	if not mode then
		return
	end

	if #queue.players >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if mode.fillTimeout > 0 then
		if #queue.players >= mode.minPlayers and not queue.fillDeadline then
			scheduleFillTimeout(modeId)
		end
		return
	end

	if #queue.players >= mode.minPlayers then
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.MODES[modeId] then
		return false, "invalid_mode"
	end

	removeFromQueue(player)

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerQueue[player] = modeId
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId then
		broadcastQueueUpdate(modeId)
		Remotes.QueueUpdate:FireClient(player, { status = "left" })
	end
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy and onArenaFree then
		onArenaFree()
	end
end

function MatchmakingService.onArenaAvailable(callback)
	onArenaFree = callback
end

function MatchmakingService.retryPendingQueues()
	for modeId in MatchmakingConfig.MODES do
		local mode = MatchmakingConfig.MODES[modeId]
		local queue = queues[modeId]
		if #queue.players >= mode.minPlayers then
			tryStartMatch(modeId)
			if arenaBusy then
				break
			end
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingConfig.QUICK_MATCH_MODE
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchmakingService.onArenaAvailable(function()
		task.delay(MatchmakingConfig.ARENA_BUSY_RETRY, function()
			MatchmakingService.retryPendingQueues()
		end)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
