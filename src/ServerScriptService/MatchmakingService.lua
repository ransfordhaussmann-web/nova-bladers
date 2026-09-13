local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local fillDeadlines = {}
local remotes
local matchReadyBindable
local arenaFreeBindable
local getRecommendedMode
local started = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function cancelFillTimer(modeId)
	local thread = fillTimers[modeId]
	if thread then
		task.cancel(thread)
		fillTimers[modeId] = nil
	end
	fillDeadlines[modeId] = nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	local mode = getModeConfig(modeId)
	if mode and #queue < mode.minPlayers then
		cancelFillTimer(modeId)
	end
end

local function buildUpdatePayload(player, modeId, status)
	local mode = getModeConfig(modeId)
	if not mode then
		return nil
	end

	local queue = ensureQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local deadline = fillDeadlines[modeId]
	local secondsLeft = nil
	if deadline then
		secondsLeft = math.max(0, math.ceil(deadline - os.clock()))
	end

	return {
		modeId = modeId,
		label = mode.label,
		position = position,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		secondsLeft = secondsLeft,
		inQueue = true,
	}
end

local function sendQueueUpdate(player, modeId, status)
	if not remotes or not player.Parent then
		return
	end
	local payload = buildUpdatePayload(player, modeId, status)
	if payload then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates(modeId, status)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		sendQueueUpdate(player, modeId, status)
	end
end

local function clearQueueUpdate(player)
	if remotes and player.Parent then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function popPlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function startMatch(modeId, players)
	cancelFillTimer(modeId)

	for _, player in players do
		clearQueueUpdate(player)
	end

	matchReadyBindable:Fire(players, modeId)
end

local function canStartMode(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return false
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end
	if #queue >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout > 0 and fillDeadlines[modeId] and os.clock() >= fillDeadlines[modeId] then
		return true
	end
	return mode.fillTimeout == 0 and #queue >= mode.minPlayers
end

local function tryStartMatch(modeId)
	if GameMatchState.isBusy() then
		broadcastQueueUpdates(modeId, "pending")
		return
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		broadcastQueueUpdates(modeId, "waiting")
		return
	end

	if #queue >= mode.maxPlayers then
		local players = popPlayers(modeId, mode.maxPlayers)
		if #players > 0 then
			startMatch(modeId, players)
		end
		return
	end

	if mode.fillTimeout > 0 then
		if not fillDeadlines[modeId] then
			fillDeadlines[modeId] = os.clock() + mode.fillTimeout
			fillTimers[modeId] = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				if canStartMode(modeId) and not GameMatchState.isBusy() then
					local currentQueue = ensureQueue(modeId)
					local players = popPlayers(modeId, #currentQueue)
					if #players >= mode.minPlayers then
						startMatch(modeId, players)
					end
				else
					tryStartMatch(modeId)
				end
			end)
		end
		broadcastQueueUpdates(modeId, "filling")
		return
	end

	if #queue >= mode.minPlayers then
		local players = popPlayers(modeId, mode.minPlayers)
		if #players > 0 then
			startMatch(modeId, players)
		end
	end
end

local function tryStartAllQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getRecommendedMode()
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	local status = if GameMatchState.isBusy() then "pending" else "waiting"
	sendQueueUpdate(player, modeId, status)
	broadcastQueueUpdates(modeId, status)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		clearQueueUpdate(player)
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	clearQueueUpdate(player)
	broadcastQueueUpdates(modeId, if GameMatchState.isBusy() then "pending" else "waiting")
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start(deps)
	if started then
		return
	end
	started = true

	remotes = deps.remotes
	matchReadyBindable = deps.matchReady
	arenaFreeBindable = deps.arenaFree
	getRecommendedMode = deps.getRecommendedMode

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	arenaFreeBindable.Event:Connect(function()
		tryStartAllQueues()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId in MatchmakingConfig.MODES do
				local queue = ensureQueue(modeId)
				if #queue > 0 then
					local status = if GameMatchState.isBusy() then
						"pending"
					elseif fillDeadlines[modeId] then
						"filling"
					else
						"waiting"
					end
					broadcastQueueUpdates(modeId, status)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
