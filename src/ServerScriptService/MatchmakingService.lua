local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local remotes
local matchReadyBindable
local running = false

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueSize(modeId)
	return #queues[modeId]
end

local function isInQueue(player)
	return playerQueue[player] ~= nil
end

local function buildQueuePayload(player, modeId, status)
	local mode = getMode(modeId)
	local list = queues[modeId]
	local position = 0
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		total = #list,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		arenaBusy = GameMatchState.isBusy(),
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent and remotes and remotes.QueueUpdate then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates(modeId, status)
	for _, player in queues[modeId] do
		sendQueueUpdate(player, buildQueuePayload(player, modeId, status))
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local list = queues[modeId]
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, i)
			break
		end
	end

	playerQueue[player] = nil

	if queueSize(modeId) < getMode(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdates(modeId, "waiting")

	if remotes and remotes.QueueUpdate then
		sendQueueUpdate(player, { inQueue = false })
	end
end

local function takePlayers(modeId, count)
	local taken = {}
	local list = queues[modeId]
	for _ = 1, math.min(count, #list) do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
			sendQueueUpdate(player, { inQueue = false, status = "matched" })
		end
	end
	return taken
end

local function startMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	if GameMatchState.isBusy() then
		broadcastQueueUpdates(modeId, "pending")
		return
	end

	if queueSize(modeId) < mode.minPlayers then
		return
	end

	local count = math.min(queueSize(modeId), mode.maxPlayers)
	local players = takePlayers(modeId, count)
	clearFillTimer(modeId)

	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	GameMatchState.setBusy(true)

	for _, player in players do
		if HubService.getPhase(player) ~= "arena" then
			HubService.leaveHubForArena(player)
		end
	end

	matchReadyBindable:Fire(players, modeId)
end

local function maybeStartFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	if queueSize(modeId) < mode.minPlayers then
		return
	end

	if queueSize(modeId) >= mode.maxPlayers then
		startMatch(modeId)
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		startMatch(modeId)
	end)
end

local function evaluateMode(modeId)
	local mode = getMode(modeId)
	if not mode or queueSize(modeId) == 0 then
		return
	end

	if GameMatchState.isBusy() then
		broadcastQueueUpdates(modeId, "pending")
		return
	end

	if modeId == "ffa" then
		if queueSize(modeId) >= mode.maxPlayers then
			startMatch(modeId)
		else
			maybeStartFillTimer(modeId)
		end
		return
	end

	if queueSize(modeId) >= mode.minPlayers then
		startMatch(modeId)
	end
end

local function evaluateAll()
	for modeId in MatchmakingConfig.MODES do
		evaluateMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false
	end

	modeId = modeId or MatchmakingConfig.DEFAULT_MODE
	local mode = getMode(modeId)
	if not mode then
		return false
	end

	if HubService.getPhase(player) == "arena" then
		return false
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local status = if GameMatchState.isBusy() then "pending" else "waiting"
	sendQueueUpdate(player, buildQueuePayload(player, modeId, status))
	broadcastQueueUpdates(modeId, status)

	evaluateMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not isInQueue(player) then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getRecommendedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	task.defer(evaluateAll)
end

function MatchmakingService.start(remotesFolder, bindablesFolder)
	remotes = remotesFolder
	matchReadyBindable = bindablesFolder.MatchReady

	running = true

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedMode()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while running do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			evaluateAll()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
