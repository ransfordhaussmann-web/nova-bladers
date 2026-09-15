--[[
	MatchmakingService — per-mode queues, fill timeouts, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaWaitStart = nil
local started = false
local onMatchStart = nil

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local count = getQueueSize(modeId)
	local pending = MatchStateService.isArenaBusy()
	local fillRemaining = nil

	if modeId == "ffa" and ffaWaitStart and count >= mode.minPlayers and count < mode.maxPlayers then
		fillRemaining = math.max(0, math.ceil(MatchmakingConfig.FFA_FILL_TIMEOUT - (os.clock() - ffaWaitStart)))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		fillRemaining = fillRemaining,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId, nil)
	for _, player in queues[modeId] do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	if modeId == "ffa" and #queue < MatchModes.get("ffa").minPlayers then
		ffaWaitStart = nil
	end

	broadcastQueue(modeId)
end

local function snapshotPlayers(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function dequeuePlayers(modeId, playerList)
	local queue = queues[modeId]
	for _, matched in playerList do
		playerQueue[matched] = nil
		for i, queued in queue do
			if queued == matched then
				table.remove(queue, i)
				break
			end
		end
	end

	if modeId == "ffa" and #queue < MatchModes.get("ffa").minPlayers then
		ffaWaitStart = nil
	end
end

local function launchMatch(modeId, playerList)
	dequeuePlayers(modeId, playerList)

	if onMatchStart then
		for _, matched in playerList do
			onMatchStart(matched)
		end
	end

	MatchReady:Fire(playerList, modeId)
	broadcastAllQueues()
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			local players = {}
			for i = 1, mode.maxPlayers do
				table.insert(players, queue[i])
			end
			launchMatch(modeId, players)
			return
		end

		if not ffaWaitStart then
			ffaWaitStart = os.clock()
			broadcastQueue(modeId)
			return
		end

		if os.clock() - ffaWaitStart >= MatchmakingConfig.FFA_FILL_TIMEOUT then
			launchMatch(modeId, snapshotPlayers(modeId))
		end
		return
	end

	launchMatch(modeId, snapshotPlayers(modeId))
end

local function evaluateQueues()
	for modeId in queues do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end

	if MatchStateService.isArenaBusy() and playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if modeId == "ffa" and getQueueSize(modeId) >= MatchModes.get("ffa").minPlayers and not ffaWaitStart then
		ffaWaitStart = os.clock()
	end

	broadcastQueue(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.setOnMatchStart(callback)
	onMatchStart = callback
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		task.delay(MatchmakingConfig.ARENA_BUSY_RETRY, evaluateQueues)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			evaluateQueues()
		end
	end)
end

return MatchmakingService
