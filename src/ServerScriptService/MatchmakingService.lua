local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil

local Remotes
local MatchReady
local ArenaFree

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getFillSecondsLeft(queue, mode)
	if not mode.fillTimeout or not queue.fillDeadline then
		return nil
	end
	return math.max(0, math.ceil(queue.fillDeadline - os.clock()))
end

local function buildQueuePayload(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	if not mode or not queue then
		return { status = "left" }
	end

	local count = #queue.players
	local status = "waiting"
	if pendingMatch and pendingMatch.modeId == modeId then
		for _, queuedPlayer in pendingMatch.players do
			if queuedPlayer == player then
				status = "pending"
				break
			end
		end
	end

	return {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		needed = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		fillSecondsLeft = getFillSecondsLeft(queue, mode),
		inQueue = true,
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		local modeId = playerQueue[player]
		if modeId then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearFillDeadline(modeId)
	local queue = queues[modeId]
	if queue then
		queue.fillDeadline = nil
	end
end

local function maybeStartFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	if not mode or not queue or modeId ~= "ffa" then
		return
	end
	if #queue.players >= mode.minPlayers and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + mode.fillTimeout
	end
end

local function removePlayerFromModeQueue(player, modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if mode and #queue.players < mode.minPlayers then
		clearFillDeadline(modeId)
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	removePlayerFromModeQueue(player, modeId)

	if pendingMatch then
		for index, queuedPlayer in pendingMatch.players do
			if queuedPlayer == player then
				table.remove(pendingMatch.players, index)
				break
			end
		end
		if #pendingMatch.players == 0 then
			pendingMatch = nil
		end
	end

	if not silent then
		Remotes.QueueUpdate:FireClient(player, { status = "left", inQueue = false })
		broadcastQueueUpdate()
	end
end

local function canStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	if not mode or not queue or #queue.players < mode.minPlayers then
		return false
	end

	if #queue.players >= mode.maxPlayers then
		return true
	end

	if modeId == "ffa" and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true
	end

	return mode.minPlayers == mode.maxPlayers
end

local function popMatchPlayers(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	local matchPlayers = {}

	for index = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(matchPlayers, queue.players[index])
	end

	local remaining = {}
	for index = mode.maxPlayers + 1, #queue.players do
		table.insert(remaining, queue.players[index])
	end

	queue.players = remaining
	clearFillDeadline(modeId)

	for _, player in matchPlayers do
		playerQueue[player] = nil
	end

	return matchPlayers
end

local function dismissQueueUi(matchPlayers)
	for _, player in matchPlayers do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { status = "left", inQueue = false })
		end
	end
end

local function launchMatch(modeId, matchPlayers)
	dismissQueueUi(matchPlayers)
	GameMatchState.setArenaBusy(true)
	MatchReady:Fire(modeId, matchPlayers)
end

local function tryStartMatch(modeId)
	if not canStartMatch(modeId) then
		return
	end

	local matchPlayers = popMatchPlayers(modeId)
	if #matchPlayers == 0 then
		return
	end

	if GameMatchState.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = matchPlayers,
		}
		for _, player in matchPlayers do
			Remotes.QueueUpdate:FireClient(player, {
				status = "pending",
				modeId = modeId,
				modeLabel = MatchmakingConfig.getMode(modeId).label,
				count = #matchPlayers,
				inQueue = true,
			})
		end
		return
	end

	launchMatch(modeId, matchPlayers)
	broadcastQueueUpdate()
end

local function joinQueue(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	removeFromQueue(player, true)
	playerQueue[player] = modeId
	table.insert(queues[modeId].players, player)
	maybeStartFillTimer(modeId)

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate()
	tryStartMatch(modeId)
	return true
end

local function flushPendingMatch()
	if not pendingMatch or GameMatchState.isArenaBusy() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	launchMatch(match.modeId, match.players)
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.joinQueue(player, modeId)
	return joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.start()
	local bindables
	Remotes, bindables = RemotesSetup.ensure()
	MatchReady = bindables.MatchReady
	ArenaFree = bindables.ArenaFree

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = getRecommendedModeId()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		removeFromQueue(player)
	end)

	ArenaFree.Event:Connect(function()
		GameMatchState.setArenaBusy(false)
		flushPendingMatch()
		for modeId in queues do
			tryStartMatch(modeId)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			for modeId, queue in queues do
				if modeId == "ffa" and queue.fillDeadline and os.clock() >= queue.fillDeadline then
					tryStartMatch(modeId)
				end
			end
		end
	end)
end

return MatchmakingService
