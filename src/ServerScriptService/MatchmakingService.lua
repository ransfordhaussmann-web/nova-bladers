--[[
	MatchmakingService — per-mode queues with Training / PvP / FFA fill rules.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local remotes
local bindables
local arenaBusy = false
local queues = {}
local playerQueue = {}
local fillTimers = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
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

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return { inQueue = false }
	end

	local count = queueCount(modeId)
	local status = "waiting"
	if arenaBusy then
		status = "pending"
	elseif count >= mode.minPlayers and modeId == "ffa" and fillTimers[modeId] then
		status = "filling"
	end

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}
end

local function sendQueueUpdate(player)
	if not remotes or not remotes.QueueUpdate then
		return
	end

	local modeId = playerQueue[player]
	if modeId then
		remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	else
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function broadcastQueueUpdates(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function broadcastAllQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			sendQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(matchPlayers, player)
		end
	end

	return matchPlayers
end

local function startMatch(modeId)
	local mode = getMode(modeId)
	if not mode or arenaBusy then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	local matchPlayers = popPlayers(modeId)
	if #matchPlayers < mode.minPlayers then
		for _, player in matchPlayers do
			table.insert(queue, player)
			playerQueue[player] = modeId
		end
		return
	end

	arenaBusy = true
	broadcastAllQueueUpdates()

	if bindables and bindables.MatchReady then
		bindables.MatchReady:Fire({
			mode = modeId,
			players = matchPlayers,
		})
	end
end

local function tryStartMode(modeId)
	local mode = getMode(modeId)
	if not mode or arenaBusy then
		return
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if fillTimers[modeId] then
			return
		end

		broadcastQueueUpdates(modeId)
		fillTimers[modeId] = task.delay(mode.fillTimeout, function()
			fillTimers[modeId] = nil
			startMatch(modeId)
			MatchmakingService.processQueues()
		end)
		return
	end

	startMatch(modeId)
end

function MatchmakingService.processQueues()
	if arenaBusy then
		return
	end

	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	broadcastAllQueueUpdates()
	if not busy then
		MatchmakingService.processQueues()
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not isValidMode(modeId) then
		return false, "Ungültiger Modus"
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	MatchmakingService.processQueues()

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	MatchmakingService.processQueues()
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.init(remoteFolder, bindableFolder)
	remotes = remoteFolder
	bindables = bindableFolder

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if bindables.MatchEnded then
		bindables.MatchEnded.Event:Connect(function()
			MatchmakingService.setArenaBusy(false)
		end)
	end

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId in MatchmakingConfig.MODES do
				if #queues[modeId] > 0 then
					broadcastQueueUpdates(modeId)
				end
			end
		end
	end)
end

return MatchmakingService
