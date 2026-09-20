--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

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

local queues = {}
local playerMode = {}
local fillTokens = {}
local fillDeadlines = {}
local onArenaEnter = nil

for modeId in MatchModes do
	queues[modeId] = {}
end

local function getQueueIndex(modeId, player)
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	local index = getQueueIndex(modeId, player)
	if index then
		table.remove(queue, index)
	end
	playerMode[player] = nil

	if fillTokens[modeId] then
		fillTokens[modeId] = nil
		fillDeadlines[modeId] = nil
	end
end

local function getQueueStatus(modeId, player)
	if MatchStateService.isBusy() then
		return "pending_arena"
	end

	local mode = MatchModes[modeId]
	local queue = queues[modeId]
	local count = #queue

	if mode.fillTimeout and count >= mode.minPlayers then
		local deadline = fillDeadlines[modeId]
		if deadline and deadline > os.clock() then
			return "filling"
		end
	end

	if count >= mode.maxPlayers then
		return "starting"
	end

	if modeId == "training" and count >= 1 then
		return "starting"
	end

	if modeId == "pvp" and count >= 2 then
		return "starting"
	end

	return "waiting"
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes[modeId]
	local queue = queues[modeId]
	local index = getQueueIndex(modeId, player) or 0
	local deadline = fillDeadlines[modeId]
	local fillRemaining = nil

	if deadline and deadline > os.clock() then
		fillRemaining = math.ceil(deadline - os.clock())
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = index,
		total = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = getQueueStatus(modeId, player),
		fillRemaining = fillRemaining,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerMode[player]
	if not modeId then
		QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
end

local function broadcastQueueUpdates()
	for player in playerMode do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerMode[player] = nil
		end
	end
	return picked
end

local function dispatchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if onArenaEnter then
		for _, player in playerList do
			onArenaEnter(player)
		end
	end

	MatchReady:Fire(playerList, modeId)
	broadcastQueueUpdates()
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		return false
	end

	local mode = MatchModes[modeId]
	local queue = queues[modeId]
	local count = #queue

	if modeId == "training" then
		if count < 1 then
			return false
		end
		dispatchMatch(modeId, popPlayers(modeId, 1))
		return true
	end

	if modeId == "pvp" then
		if count < mode.minPlayers then
			return false
		end
		dispatchMatch(modeId, popPlayers(modeId, 2))
		return true
	end

	if modeId == "ffa" then
		if count < mode.minPlayers then
			return false
		end

		local deadline = fillDeadlines[modeId]
		local timedOut = deadline and os.clock() >= deadline
		local full = count >= mode.maxPlayers

		if full then
			dispatchMatch(modeId, popPlayers(modeId, mode.maxPlayers))
			fillTokens[modeId] = nil
			fillDeadlines[modeId] = nil
			return true
		end

		if timedOut then
			dispatchMatch(modeId, popPlayers(modeId, count))
			fillTokens[modeId] = nil
			fillDeadlines[modeId] = nil
			return true
		end
	end

	return false
end

local function tryAllQueues()
	for modeId in MatchModes do
		if tryStartMatch(modeId) then
			return
		end
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes[modeId]
	if not mode.fillTimeout then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if fillTokens[modeId] then
		return
	end

	fillTokens[modeId] = {}
	fillDeadlines[modeId] = os.clock() + mode.fillTimeout
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		fillTokens[modeId] = nil
		fillDeadlines[modeId] = nil
		tryStartMatch(modeId)
		broadcastQueueUpdates()
	end)

	broadcastQueueUpdates()
end

local function joinQueueInternal(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes[modeId] then
		return
	end

	if playerMode[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	sendQueueUpdate(player)
	broadcastQueueUpdates()

	if modeId == "ffa" then
		startFillTimer(modeId)
	end

	if not MatchStateService.isBusy() then
		tryStartMatch(modeId)
	end
end

local function leaveQueue(player)
	if not playerMode[player] then
		QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	removeFromQueue(player)
	QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdates()
end

function MatchmakingService.init(handlers)
	onArenaEnter = handlers and handlers.onArenaEnter

	MatchStateService.onArenaFreed(function()
		tryAllQueues()
		broadcastQueueUpdates()
	end)

	MatchEnded.Event:Connect(function()
		MatchStateService.setBusy(false)
	end)

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		joinQueueInternal(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			local hasFillTimer = false
			for modeId, deadline in fillDeadlines do
				if deadline and deadline > os.clock() then
					hasFillTimer = true
					break
				end
			end
			if hasFillTimer or MatchStateService.isBusy() then
				broadcastQueueUpdates()
			end
		end
	end)
end

function MatchmakingService.getSuggestedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinSuggested(player)
	joinQueueInternal(player, MatchmakingService.getSuggestedMode())
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueueInternal(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

return MatchmakingService
