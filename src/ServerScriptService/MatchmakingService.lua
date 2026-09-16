local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local started = false

local function initQueues()
	for _, mode in MatchModes do
		queues[mode.id] = {
			players = {},
			fillDeadline = nil,
		}
	end
end

local function getQueueSize(modeId)
	return #queues[modeId].players
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
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	local index = playerInList(queue.players, player)
	if index then
		table.remove(queue.players, index)
	end

	if getQueueSize(entry.modeId) < MatchModes.get(entry.modeId).minPlayers then
		queue.fillDeadline = nil
	end

	playerEntry[player] = nil
end

local function getPlayerStatus(modeId)
	if MatchStateService.isArenaBusy() then
		return "pending"
	end
	return "waiting"
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local total = getQueueSize(modeId)
	local entry = playerEntry[player]
	local fillRemaining = nil

	if queue.fillDeadline and modeId == "ffa" then
		fillRemaining = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = playerInList(queue.players, player) or total,
		total = total,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = entry and entry.status or getPlayerStatus(modeId),
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId].players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			table.insert(taken, player)
			playerEntry[player] = nil
		end
	end
	queue.fillDeadline = nil
	return taken
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		return
	end

	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	local shouldStart = false
	local playerCount = size

	if modeId == "ffa" then
		local queue = queues[modeId]
		if size >= mode.maxPlayers then
			shouldStart = true
			playerCount = mode.maxPlayers
		elseif queue.fillDeadline and os.clock() >= queue.fillDeadline then
			shouldStart = true
			playerCount = size
		end
	else
		shouldStart = size >= mode.minPlayers
		playerCount = mode.minPlayers
	end

	if not shouldStart then
		return
	end

	local players = takePlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	MatchReady:Fire({
		mode = modeId,
		players = players,
	})

	broadcastAllQueues()
end

local function evaluateQueues()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false, "invalid_mode"
	end

	if playerEntry[player] then
		if playerEntry[player].modeId == modeId then
			return true
		end
		removeFromQueue(player)
	end

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerEntry[player] = {
		modeId = modeId,
		status = getPlayerStatus(modeId),
	}

	local mode = MatchModes.get(modeId)
	if modeId == "ffa" and getQueueSize(modeId) >= mode.minPlayers and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	end

	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return false
	end

	local modeId = playerEntry[player].modeId
	removeFromQueue(player)
	broadcastQueue(modeId)
	return true
end

function MatchmakingService.getPlayerQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end
	return buildQueuePayload(player, entry.modeId)
end

function MatchmakingService.onArenaFreed()
	for modeId in queues do
		for _, player in queues[modeId].players do
			if playerEntry[player] then
				playerEntry[player].status = "waiting"
			end
		end
		broadcastQueue(modeId)
	end
	evaluateQueues()
end

function MatchmakingService.onArenaBusy()
	for modeId in queues do
		for _, player in queues[modeId].players do
			if playerEntry[player] then
				playerEntry[player].status = "pending"
			end
		end
		broadcastQueue(modeId)
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true
	initQueues()

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for modeId in queues do
				local queue = queues[modeId]
				if queue.fillDeadline and os.clock() >= queue.fillDeadline then
					tryStartMatch(modeId)
				end
			end
		end
	end)
end

return MatchmakingService
