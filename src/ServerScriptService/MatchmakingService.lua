local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady
local queues = {}
local playerQueue = {}
local fillTimers = {}
local config = {}

for modeId in MatchModes do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function countQueue(modeId)
	return #queues[modeId]
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end
	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = { expired = false }
	task.delay(mode.fillTimeout, function()
		local timer = fillTimers[modeId]
		if not timer then
			return
		end
		timer.expired = true
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	if countQueue(modeId) == 0 then
		clearFillTimer(modeId)
	end
end

local function getQueueStatus(modeId)
	local mode = getMode(modeId)
	if not mode then
		return "waiting"
	end

	if MatchStateService.isArenaBusy() then
		return "pending"
	end

	local count = countQueue(modeId)
	if count >= mode.maxPlayers then
		return "starting"
	end
	if mode.fillTimeout > 0 and fillTimers[modeId] and fillTimers[modeId].expired and count >= mode.minPlayers then
		return "starting"
	end
	return "waiting"
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = getMode(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = countQueue(modeId),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = getQueueStatus(modeId),
	}
end

local function sendQueueUpdate(player)
	if not Remotes then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
end

local function broadcastQueueUpdates(modeId)
	for player, queuedModeId in playerQueue do
		if queuedModeId == modeId and player.Parent then
			sendQueueUpdate(player)
		end
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	local modeId = playerQueue[player]
	removeFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end
	if config.getPhase and config.getPhase(player) ~= "hub" then
		return
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if countQueue(modeId) == 1 then
		startFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return false
	end

	local queue = queues[modeId]
	local count = #queue
	if count < mode.minPlayers then
		broadcastQueueUpdates(modeId)
		return false
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return false
	end

	if count < mode.maxPlayers and mode.fillTimeout > 0 then
		local timer = fillTimers[modeId]
		if not timer or not timer.expired then
			broadcastQueueUpdates(modeId)
			return false
		end
	end

	local matchPlayers = {}
	local take = math.min(count, mode.maxPlayers)
	for i = 1, take do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end
	clearFillTimer(modeId)

	for _, player in matchPlayers do
		if config.leaveHubForArena then
			config.leaveHubForArena(player)
		end
		sendQueueUpdate(player)
	end

	if MatchReady then
		MatchReady:Fire(matchPlayers)
	end

	broadcastQueueUpdates(modeId)
	return true
end

function MatchmakingService.onArenaFree()
	for modeId in queues do
		if countQueue(modeId) > 0 then
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.init(handlers)
	config = handlers or {}
	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
