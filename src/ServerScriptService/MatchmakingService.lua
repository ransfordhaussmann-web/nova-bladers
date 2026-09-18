local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingLaunch = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function queueCount(modeId)
	return #getQueue(modeId)
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local count = queueCount(modeId)
	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif count >= mode.maxPlayers then
		status = "full"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		label = mode.label,
		desc = mode.desc,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = playerQueue[player] == modeId,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			local payload = buildQueuePayload(modeId, queuedPlayer)
			if payload then
				Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
			end
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function takePlayers(modeId, amount)
	local queue = getQueue(modeId)
	local taken = {}
	local limit = math.min(amount or #queue, #queue)

	for _ = 1, limit do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerQueue[nextPlayer] = nil
			table.insert(taken, nextPlayer)
		end
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	broadcastQueueUpdate(modeId)
	return taken
end

local function canLaunch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout and count >= mode.minPlayers then
		return fillTimers[modeId] == nil
	end
	return count >= mode.minPlayers
end

local function launchMatch(modeId)
	if MatchStateService.isArenaBusy() then
		pendingLaunch[modeId] = true
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode or not canLaunch(modeId) then
		return
	end

	pendingLaunch[modeId] = false
	local players = takePlayers(modeId, mode.maxPlayers)
	if #players < mode.minPlayers then
		for _, queuedPlayer in players do
			MatchmakingService.joinQueue(queuedPlayer, modeId)
		end
		return
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(modeId, players)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	if queueCount(modeId) < mode.minPlayers then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		launchMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	if not canLaunch(modeId) then
		if queueCount(modeId) >= (MatchModes.get(modeId) or {}).minPlayers then
			scheduleFillTimeout(modeId)
		end
		broadcastQueueUpdate(modeId)
		return
	end

	launchMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end

	if playerQueue[player] == modeId then
		broadcastQueueUpdate(modeId)
		return true
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(modeId)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	removeFromQueue(player)
	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.getQueueSnapshot(modeId, player)
	return buildQueuePayload(modeId, player)
end

function MatchmakingService.onArenaFreed()
	broadcastAllQueues()

	for modeId in pendingLaunch do
		if pendingLaunch[modeId] then
			evaluateQueue(modeId)
		end
	end

	for modeId in queues do
		if queueCount(modeId) > 0 then
			evaluateQueue(modeId)
		end
	end
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)
end

return MatchmakingService
