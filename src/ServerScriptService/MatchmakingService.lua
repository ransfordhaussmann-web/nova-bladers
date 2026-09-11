local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {
		players = {},
		fillDeadline = nil,
		fillToken = 0,
	}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function findQueuePosition(queue, player)
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			return index
		end
	end
	return 0
end

local function buildQueuePayload(modeId, player)
	local queue = queues[modeId]
	local mode = getMode(modeId)
	local status = "waiting"

	if arenaBusy then
		status = "pending"
	elseif #queue.players >= mode.maxPlayers then
		status = "starting"
	elseif queue.fillDeadline and os.clock() >= queue.fillDeadline then
		status = "starting"
	end

	return {
		joined = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = findQueuePosition(queue, player),
		total = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = queue.fillDeadline
			and math.max(0, math.ceil(queue.fillDeadline - os.clock()))
			or nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue.players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function clearFillTimer(modeId)
	local queue = queues[modeId]
	queue.fillDeadline = nil
	queue.fillToken += 1
end

local function startFillTimer(modeId)
	local queue = queues[modeId]
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 or mode.minPlayers == mode.maxPlayers then
		return
	end
	if #queue.players < mode.minPlayers or queue.fillDeadline then
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
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function canStartMatch(modeId)
	if arenaBusy then
		return false
	end

	local queue = queues[modeId]
	local mode = getMode(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.minPlayers == mode.maxPlayers then
		return count >= mode.minPlayers
	end
	if queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true
	end

	return false
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	broadcastAllQueues()
	if not busy then
		for modeId in queues do
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.tryStartMatch(modeId)
	if not canStartMatch(modeId) then
		return false
	end

	local queue = queues[modeId]
	local mode = getMode(modeId)
	local matchPlayers = {}
	for index = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(matchPlayers, queue.players[index])
	end

	if #matchPlayers < mode.minPlayers then
		return false
	end

	for _, player in matchPlayers do
		playerQueue[player] = nil
	end

	local remaining = {}
	for index = #matchPlayers + 1, #queue.players do
		table.insert(remaining, queue.players[index])
	end
	queue.players = remaining
	clearFillTimer(modeId)

	for _, player in matchPlayers do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				joined = false,
				status = "starting",
				modeId = modeId,
				modeLabel = mode.label,
			})
		end
	end

	if #queue.players >= mode.minPlayers then
		startFillTimer(modeId)
	end
	broadcastQueueUpdate(modeId)

	arenaBusy = true
	Bindables.MatchReady:Fire(matchPlayers, modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	MatchmakingService.leaveQueue(player, true)

	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)

	if mode.minPlayers == mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif #queues[modeId].players >= mode.minPlayers then
		startFillTimer(modeId)
		MatchmakingService.tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end
	playerQueue[player] = nil

	local mode = getMode(modeId)
	if #queue.players < mode.minPlayers then
		clearFillTimer(modeId)
	end

	if not silent and player.Parent then
		Remotes.QueueUpdate:FireClient(player, { joined = false })
	end
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player, true)
end)

return MatchmakingService
