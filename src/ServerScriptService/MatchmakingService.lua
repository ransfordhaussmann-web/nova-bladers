--[[
	MatchmakingService — per-mode queues, FFA fill timeout, pending when arena is busy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local pendingPlayers = {}
local started = false

local function getQueue(modeId)
	return queues[modeId]
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

	if modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		fillTimers.ffa = nil
	end
end

local function buildQueuePayload(modeId, player, status)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = #queue,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = status or "waiting",
	}
end

local function broadcastQueue(modeId, status)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player, status))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function filterValidPlayers(playerList)
	local valid = {}
	for _, player in playerList do
		if player.Parent then
			table.insert(valid, player)
		end
	end
	return valid
end

local function clearPending(player)
	pendingPlayers[player] = nil
end

local function markPending(modeId, playerList)
	for _, player in playerList do
		pendingPlayers[player] = modeId
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player, "pending"))
		end
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	local limit = math.min(count, #queue)

	for _ = 1, limit do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end

	return taken
end

local function launchMatch(modeId, playerList)
	local players = filterValidPlayers(playerList)
	if #players == 0 then
		return
	end

	local mode = MatchModes.get(modeId)
	if #players < mode.minPlayers then
		broadcastQueue(modeId)
		return
	end

	for _, player in players do
		clearPending(player)
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			modeLabel = mode.label,
			playersInQueue = #players,
			playersNeeded = mode.minPlayers,
			maxPlayers = mode.maxPlayers,
			position = 0,
			status = "starting",
		})
		HubService.leaveForArena(player)
	end

	MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

local function getReadyCount(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return nil
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			fillTimers.ffa = nil
			return mode.maxPlayers
		end

		if not fillTimers.ffa then
			fillTimers.ffa = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
			return nil
		end

		if os.clock() < fillTimers.ffa then
			return nil
		end

		fillTimers.ffa = nil
		return #queue
	end

	return mode.maxPlayers
end

local function tryStartMode(modeId)
	local readyCount = getReadyCount(modeId)
	if not readyCount then
		return
	end

	local reserved = {}
	for i = 1, readyCount do
		table.insert(reserved, getQueue(modeId)[i])
	end

	if MatchStateService.isBusy() then
		markPending(modeId, reserved)
		return
	end

	local players = takePlayersFromQueue(modeId, readyCount)
	launchMatch(modeId, players)
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if playerQueue[player] == modeId then
		return
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	broadcastQueue(modeId)
	tryStartMode(modeId)
end

local function leaveQueue(player)
	local modeId = playerQueue[player] or pendingPlayers[player]
	if not modeId then
		return
	end

	clearPending(player)
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, {
		modeId = modeId,
		status = "left",
	})
	broadcastQueue(modeId)
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= MatchModes.ffa.minPlayers then
		return "ffa"
	elseif count >= MatchModes.pvp.minPlayers then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId or getRecommendedModeId())
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	local _, Bindables = RemotesSetup.ensure()
	Remotes = ReplicatedStorage.NovaBladers.Remotes
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "quick" then
			modeId = getRecommendedModeId()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearPending(player)
		removeFromQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		for modeId in queues do
			tryStartMode(modeId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			for modeId in queues do
				if modeId == "ffa" and fillTimers.ffa and os.clock() >= fillTimers.ffa then
					tryStartMode("ffa")
				end
				if #getQueue(modeId) > 0 then
					broadcastQueue(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
