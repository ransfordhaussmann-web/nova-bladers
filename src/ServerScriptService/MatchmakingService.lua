local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local broadcastScheduled = false

local function getQueue(modeId)
	return queues[modeId]
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
		return
	end

	local queue = getQueue(modeId)
	local index = playerInList(queue, player)
	if index then
		table.remove(queue, index)
	end
	playerQueue[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId] = nil
	end
end

local function getPlayerNames(queue)
	local names = {}
	for _, player in queue do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end
	return names
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local index = playerInList(queue, player)
	local count = #queue
	local status = "waiting"

	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif mode.needsFillTimeout and count >= mode.minPlayers and fillTimers[modeId] then
		status = "filling"
	end

	local fillTimeLeft = nil
	if fillTimers[modeId] then
		fillTimeLeft = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = getPlayerNames(queue),
		position = index or 0,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeLeft = fillTimeLeft,
		inQueue = index ~= nil,
	}
end

local function broadcastQueueUpdates()
	broadcastScheduled = false

	for modeId in queues do
		local queue = getQueue(modeId)
		for _, player in queue do
			if player.Parent then
				QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
			end
		end
	end
end

local function scheduleBroadcast()
	if broadcastScheduled then
		return
	end
	broadcastScheduled = true
	task.delay(MatchmakingConfig.QUEUE_BROADCAST_DEBOUNCE, broadcastQueueUpdates)
end

local tryStartMatch

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	local endsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	fillTimers[modeId] = { endsAt = endsAt }
	scheduleBroadcast()

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if fillTimers[modeId] and fillTimers[modeId].endsAt == endsAt then
			tryStartMatch(modeId)
		end
	end)

	task.spawn(function()
		while fillTimers[modeId] and fillTimers[modeId].endsAt == endsAt do
			task.wait(1)
			if fillTimers[modeId] then
				scheduleBroadcast()
			end
		end
	end)
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.needsFillTimeout and fillTimers[modeId] then
		return os.clock() >= fillTimers[modeId].endsAt
	end
	return not mode.needsFillTimeout
end

local function popPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local matched = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(matched, player)
			playerQueue[player] = nil
		end
	end

	clearFillTimer(modeId)
	return matched
end

tryStartMatch = function(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		clearFillTimer(modeId)
		return
	end

	if mode.needsFillTimeout and count < mode.maxPlayers then
		if not fillTimers[modeId] then
			startFillTimer(modeId)
			return
		end
	end

	if not canStartMatch(modeId) then
		return
	end

	local players = popPlayersForMatch(modeId)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queue, player)
			playerQueue[player] = modeId
		end
		return
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire({
		players = players,
		modeId = modeId,
	})
	scheduleBroadcast()
end

local function evaluateQueues()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	scheduleBroadcast()
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	QueueUpdate:FireClient(player, { inQueue = false })
	scheduleBroadcast()
	tryStartMatch(modeId)
end

function MatchmakingService.getRecommendedMode()
	return MatchModes.getRecommended(#Players:GetPlayers())
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(evaluateQueues)
end

function MatchmakingService.init(hubCallbacks)
	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedMode()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		scheduleBroadcast()
	end)

	if hubCallbacks then
		if hubCallbacks.onPortalJoin then
			hubCallbacks.onPortalJoin(function(player)
				MatchmakingService.joinQueue(player, MatchmakingService.getRecommendedMode())
			end)
		end

		if hubCallbacks.onModePadJoin then
			hubCallbacks.onModePadJoin(function(player, modeId)
				MatchmakingService.joinQueue(player, modeId)
			end)
		end
	end

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
