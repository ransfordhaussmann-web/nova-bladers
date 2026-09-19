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

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local updateLoop = nil

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getPlayerNames(playerList)
	local names = {}
	for _, player in playerList do
		table.insert(names, player.Name)
	end
	return names
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil

	if #queue == 0 and fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId, queue, status, fillRemaining)
	local mode = MatchModes.get(modeId)
	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		players = getPlayerNames(queue),
		current = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueue(modeId, status, fillRemaining)
	local queue = getQueue(modeId)
	local payload = buildQueuePayload(modeId, queue, status, fillRemaining)
	for _, player in queue do
		if player.Parent then
			QueueUpdate:FireClient(player, payload)
		end
	end
end

local function getQueueStatus()
	if MatchStateService.isActive() then
		return "pending"
	end
	return "waiting"
end

local function broadcastAllQueues()
	for modeId in queues do
		local queue = getQueue(modeId)
		if #queue > 0 then
			broadcastQueue(modeId, getQueueStatus(), nil)
		end
	end
end

local function isQueueReady(modeId, queue, fillExpired)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end
	if #queue >= mode.maxPlayers then
		return true
	end
	if modeId == "ffa" then
		return fillExpired == true and #queue >= mode.minPlayers
	end
	return #queue >= mode.minPlayers and mode.minPlayers == mode.maxPlayers
end

local function takeReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local ready = {}
	for i = 1, count do
		table.insert(ready, queue[i])
	end

	for _, player in ready do
		removeFromQueue(player)
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	return ready
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local deadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	fillTimers[modeId] = task.spawn(function()
		while os.clock() < deadline do
			local remaining = math.ceil(deadline - os.clock())
			broadcastQueue(modeId, getQueueStatus(), remaining)
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		end
		fillTimers[modeId] = nil

		if MatchStateService.isActive() then
			return
		end

		local queue = getQueue(modeId)
		if isQueueReady(modeId, queue, true) then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.tryStartMatch(modeId, fillExpired)
	if MatchStateService.isActive() then
		broadcastAllQueues()
		return
	end

	local queue = getQueue(modeId)
	if not isQueueReady(modeId, queue, fillExpired == true) then
		return
	end

	local players = takeReadyPlayers(modeId)
	if #players == 0 then
		return
	end

	broadcastQueue(modeId, "starting", nil)

	task.delay(MatchmakingConfig.MATCH_START_DELAY, function()
		local valid = {}
		for _, player in players do
			if player.Parent then
				table.insert(valid, player)
			end
		end
		if #valid == 0 then
			return
		end
		MatchReady:Fire(valid, modeId)
	end)
end

local function onQueueChanged(modeId)
	local queue = getQueue(modeId)
	local mode = MatchModes.get(modeId)

	if modeId == "ffa" and #queue >= mode.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId)
	end

	if isQueueReady(modeId, queue, false) then
		MatchmakingService.tryStartMatch(modeId, false)
		return
	end

	local status = getQueueStatus()
	local fillRemaining = nil
	if fillTimers[modeId] then
		fillRemaining = MatchmakingConfig.FFA_FILL_TIMEOUT
	end
	broadcastQueue(modeId, status, fillRemaining)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return
	end

	for _, p in queue do
		if p == player then
			return
		end
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	QueueUpdate:FireClient(player, { status = "left" })
	onQueueChanged(modeId)
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.getRecommended(count)
	MatchmakingService.joinQueue(player, mode.id)
end

function MatchmakingService.init(hubCallbacks)
	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.setOnMatchEnd(function()
		task.defer(function()
			for modeId in queues do
				local queue = getQueue(modeId)
				local mode = MatchModes.get(modeId)
				if modeId == "ffa" and mode and #queue >= mode.minPlayers and not fillTimers[modeId] then
					startFillTimer(modeId)
				end
			end
			broadcastAllQueues()
			for modeId in queues do
				MatchmakingService.tryStartMatch(modeId, false)
			end
		end)
	end)

	if not updateLoop then
		updateLoop = task.spawn(function()
			while true do
				task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
				for modeId in queues do
					local queue = getQueue(modeId)
					if #queue > 0 then
						broadcastQueue(modeId, getQueueStatus(), nil)
					end
				end
			end
		end)
	end

	MatchmakingService._hubCallbacks = hubCallbacks
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

return MatchmakingService
