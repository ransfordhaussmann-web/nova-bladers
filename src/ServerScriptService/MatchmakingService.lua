local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady, MatchEnded
local QueueJoinRemote, QueueLeaveRemote, QueueUpdateRemote

local queues = {}
local playerQueue = {}
local fillTokens = {}
local fillEndsAt = {}
local callbacks = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function queueContains(queue, player)
	for _, queuedPlayer in queue do
		if queuedPlayer == player then
			return true
		end
	end
	return false
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerQueue[player] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillEndsAt[modeId] = nil
end

local function getStatus(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return "waiting"
	end

	if MatchStateService.isArenaBusy() then
		return "pending"
	end

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return "starting"
	end

	if #queue >= mode.minPlayers and mode.fillTimeout > 0 and fillEndsAt[modeId] then
		return "filling"
	end

	return "waiting"
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = getQueue(modeId)
	local status = getStatus(modeId)
	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}

	if status == "filling" and fillEndsAt[modeId] then
		payload.fillSecondsLeft = math.max(0, math.ceil(fillEndsAt[modeId] - os.clock()))
	end

	return payload
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		QueueUpdateRemote:FireClient(player, { inQueue = false })
		return
	end

	QueueUpdateRemote:FireClient(player, buildQueuePayload(player, modeId))
end

local function broadcastQueueUpdates(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillEndsAt[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	fillEndsAt[modeId] = os.clock() + mode.fillTimeout
	broadcastQueueUpdates(modeId)

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if #queue < mode.maxPlayers and mode.fillTimeout > 0 and not fillEndsAt[modeId] then
		startFillTimer(modeId)
		return
	end

	cancelFillTimer(modeId)

	local matchPlayers = {}
	for index = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[index])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	if #matchPlayers == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	for _, player in matchPlayers do
		QueueUpdateRemote:FireClient(player, {
			inQueue = false,
			status = "starting",
			modeId = modeId,
			modeLabel = mode.label,
		})
	end

	MatchReady:Fire({
		modeId = modeId,
		players = matchPlayers,
	})
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			sendQueueUpdate(player)
			return
		end
		MatchmakingService.leaveQueue(player)
	end

	if callbacks.getPhase and callbacks.getPhase(player) ~= "hub" then
		return
	end

	local queue = getQueue(modeId)
	if queueContains(queue, player) then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)

	if #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if mode.minPlayers == 1 and #queue >= 1 then
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if #queue >= mode.minPlayers then
		if mode.fillTimeout > 0 then
			if not fillEndsAt[modeId] then
				startFillTimer(modeId)
			else
				broadcastQueueUpdates(modeId)
			end
		else
			MatchmakingService.tryStartMatch(modeId)
		end
		return
	end

	broadcastQueueUpdates(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player)
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)

	for modeId, _ in pairs(queues) do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.init(hubCallbacks)
	callbacks = hubCallbacks or {}

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	MatchEnded = Bindables.MatchEnded
	QueueJoinRemote = Remotes.QueueJoin
	QueueLeaveRemote = Remotes.QueueLeave
	QueueUpdateRemote = Remotes.QueueUpdate

	QueueJoinRemote.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeaveRemote.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
