local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local fillTimerActive = {}
local hubCallbacks = {}
local initialized = false

for _, modeId in MatchModes.ORDER do
	queues[modeId] = {}
end

local function getRecommendedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function cancelFillTimer(modeId)
	fillTimerActive[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		MatchmakingService.tryStartMatch(modeId)
		return
	end
	if fillTimerActive[modeId] then
		return
	end

	fillTimerActive[modeId] = true
	task.delay(mode.fillTimeout or MatchmakingConfig.FILL_TIMEOUT, function()
		fillTimerActive[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function buildQueueStatus(modeId, player)
	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		status = status,
		position = position,
		total = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		label = mode.label,
	}
end

local function sendQueueUpdate(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueueStatus(entry.modeId, player))
end

local function broadcastQueueUpdates(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function removePlayerFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end

	local modeId = entry.modeId
	playerEntry[player] = nil

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	return modeId
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		cancelFillTimer(modeId)
		return
	end

	if #queue >= mode.maxPlayers then
		cancelFillTimer(modeId)
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if mode.fillTimeout then
		startFillTimer(modeId)
	else
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.getRecommendedMode()
	return getRecommendedMode()
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return false
	end

	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	if not mode or #queue < mode.minPlayers then
		return false
	end

	cancelFillTimer(modeId)

	local take = math.min(#queue, mode.maxPlayers)
	local players = {}
	for i = 1, take do
		players[i] = queue[i]
	end

	for i = 1, take do
		table.remove(queue, 1)
	end
	for _, player in players do
		playerEntry[player] = nil
	end

	MatchStateService.setArenaBusy(true)

	if hubCallbacks.leaveHubForArena then
		for _, player in players do
			hubCallbacks.leaveHubForArena(player)
		end
	end

	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, {
			status = "starting",
			modeId = modeId,
			label = mode.label,
		})
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = players,
	})

	broadcastQueueUpdates(modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		modeId = getRecommendedMode()
	end

	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerEntry[player] = { modeId = modeId, joinedAt = os.clock() }
	sendQueueUpdate(player)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removePlayerFromQueue(player)
	if not modeId then
		return
	end

	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	broadcastQueueUpdates(modeId)

	local mode = MatchModes.get(modeId)
	if #queues[modeId] < mode.minPlayers then
		cancelFillTimer(modeId)
	end
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)

	for _, modeId in MatchModes.ORDER do
		broadcastQueueUpdates(modeId)
		evaluateQueue(modeId)
	end
end

function MatchmakingService.init(callbacks)
	if initialized then
		return
	end
	initialized = true
	hubCallbacks = callbacks or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)
end

return MatchmakingService
