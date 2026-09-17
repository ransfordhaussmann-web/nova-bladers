local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local remotes
local matchReadyBindable

local queues = {}
local playerQueueMode = {}
local fillTokens = {}

for _, mode in MatchModes.list do
	queues[mode.id] = {
		players = {},
		fillDeadline = nil,
	}
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

local function removeFromQueue(player)
	local modeId = playerQueueMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i = #queue.players, 1, -1 do
		if queue.players[i] == player then
			table.remove(queue.players, i)
		end
	end

	if #queue.players < MatchModes.getById(modeId).minPlayers then
		queue.fillDeadline = nil
		fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	end

	playerQueueMode[player] = nil
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.getById(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	local fillRemaining
	if queue.fillDeadline then
		fillRemaining = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueueUpdates()
	for player, modeId in playerQueueMode do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function clearQueue(modeId)
	local queue = queues[modeId]
	queue.players = {}
	queue.fillDeadline = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function canStartMatch(mode)
	local queue = queues[mode.id]
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end

	if mode.instantStart then
		return count >= mode.maxPlayers
	end

	if count >= mode.maxPlayers then
		return true
	end

	if queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true
	end

	return false
end

local function startMatch(modeId)
	local mode = MatchModes.getById(modeId)
	local queue = queues[modeId]
	if not canStartMatch(mode) then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueueUpdates()
		return
	end

	local playerList = {}
	for i = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(playerList, queue.players[i])
	end

	clearQueue(modeId)
	for _, player in playerList do
		playerQueueMode[player] = nil
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		if HubService.leaveHubForArena then
			HubService.leaveHubForArena(player)
		end
	end

	MatchStateService.setBusy(true)
	matchReadyBindable:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.getById(modeId)
	if mode.instantStart or not mode.fillTimeout then
		return
	end

	local queue = queues[modeId]
	if #queue.players < mode.minPlayers then
		return
	end

	if not queue.fillDeadline then
		queue.fillDeadline = os.clock() + (mode.fillTimeout or MatchmakingConfig.FILL_TIMEOUT)
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.spawn(function()
		while token == fillTokens[modeId] and queue.fillDeadline do
			local remaining = queue.fillDeadline - os.clock()
			if remaining <= 0 then
				startMatch(modeId)
				return
			end
			broadcastQueueUpdates()
			task.wait(0.5)
		end
	end)
end

local function tryStartAllQueues()
	for _, mode in MatchModes.list do
		startMatch(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	modeId = modeId or getRecommendedModeId()
	local mode = MatchModes.getById(modeId)
	if not mode then
		return
	end

	if playerQueueMode[player] == modeId then
		broadcastQueueUpdates()
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId].players, player)
	playerQueueMode[player] = modeId

	broadcastQueueUpdates()
	scheduleFillTimer(modeId)
	tryStartAllQueues()
end

function MatchmakingService.leaveQueue(player)
	if not playerQueueMode[player] then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	removeFromQueue(player)
	remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdates()
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setBusy(false)
	tryStartAllQueues()
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.init(remoteFolder, bindables)
	remotes = remoteFolder
	matchReadyBindable = bindables.MatchReady

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = nil
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		broadcastQueueUpdates()
	end)
end

return MatchmakingService
