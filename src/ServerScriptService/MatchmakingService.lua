local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady
local ArenaFree

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local queueJoinedAt = {}
local ffaFillDeadline = nil
local started = false
local pollThread = nil

local function getQueueSize(modeId)
	return #queues[modeId]
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
	queueJoinedAt[player] = nil

	if modeId == "ffa" and #queues.ffa == 0 then
		ffaFillDeadline = nil
	end
end

local function buildQueuePayload(player, status)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queueSize = getQueueSize(modeId)
	local secondsLeft = nil
	if modeId == "ffa" and ffaFillDeadline then
		secondsLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		status = status or (GameMatchState.isArenaBusy() and "pending" or "waiting"),
		queueSize = queueSize,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		secondsLeft = secondsLeft,
		arenaBusy = GameMatchState.isArenaBusy(),
	}
end

local function sendQueueUpdate(player, status)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, status))
	end
end

local function broadcastQueueUpdates(modeId, status)
	for _, player in queues[modeId] do
		sendQueueUpdate(player, status)
	end
end

local function broadcastAllQueueUpdates()
	for modeId in queues do
		broadcastQueueUpdates(modeId)
	end
end

local function leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player)
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
end

local function canStartMode(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queueSize = getQueueSize(modeId)

	if queueSize < mode.minPlayers then
		return false
	end

	if queueSize >= mode.maxPlayers then
		return true
	end

	if modeId == "ffa" and mode.fillTimeout and ffaFillDeadline then
		return os.clock() >= ffaFillDeadline
	end

	if modeId == "training" or modeId == "pvp" then
		return queueSize >= mode.minPlayers
	end

	return false
end

local function popPlayers(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local picked = {}
	local count = math.min(#queues[modeId], mode.maxPlayers)

	for _ = 1, count do
		local player = table.remove(queues[modeId], 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerQueue[player] = nil
			queueJoinedAt[player] = nil
		end
	end

	if modeId == "ffa" and #queues.ffa == 0 then
		ffaFillDeadline = nil
	end

	return picked
end

local function startMatch(modeId, playerList)
	GameMatchState.setArenaBusy(true)

	for _, player in playerList do
		sendQueueUpdate(player, "starting")
		if HubService.getPhase(player) == "hub" then
			HubService.leaveHubForArena(player)
		end
	end

	broadcastAllQueueUpdates()
	MatchReady:Fire(modeId, playerList)
end

local function tryStartMode(modeId)
	if GameMatchState.isArenaBusy() then
		broadcastQueueUpdates(modeId, "pending")
		return
	end

	if not canStartMode(modeId) then
		broadcastQueueUpdates(modeId)
		return
	end

	local players = popPlayers(modeId)
	if #players == 0 then
		return
	end

	startMatch(modeId, players)
end

local function tryStartAllModes()
	if GameMatchState.isArenaBusy() then
		broadcastAllQueueUpdates()
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		if canStartMode(modeId) then
			tryStartMode(modeId)
			return
		end
	end

	broadcastAllQueueUpdates()
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	queueJoinedAt[player] = os.clock()

	if modeId == "ffa" and mode.fillTimeout and not ffaFillDeadline then
		ffaFillDeadline = os.clock() + mode.fillTimeout
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	tryStartAllModes()
end

local function joinRecommendedQueue(player)
	local count = #Players:GetPlayers()
	local modeId = MatchmakingConfig.getRecommendedMode(count)
	joinQueue(player, modeId)
end

local function onArenaFree()
	GameMatchState.setArenaBusy(false)
	broadcastAllQueueUpdates()
	tryStartAllModes()
end

local function onPlayerRemoving(player)
	leaveQueue(player)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, localBindables = RemotesSetup.ensure()
	MatchReady = localBindables.MatchReady
	ArenaFree = localBindables.ArenaFree

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == nil or modeId == "recommended" then
			joinRecommendedQueue(player)
		else
			joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(onPlayerRemoving)

	pollThread = task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_POLL_INTERVAL)
			if not GameMatchState.isArenaBusy() then
				tryStartAllModes()
			else
				broadcastAllQueueUpdates()
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.joinRecommended(player)
	joinRecommendedQueue(player)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

return MatchmakingService
