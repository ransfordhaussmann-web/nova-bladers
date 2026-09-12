local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local arenaBusy = false
local launching = false
local fillTimers = {}
local started = false
local onMatchReady

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
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

	if modeId == "ffa" and #queue < MatchmakingConfig.MODES.ffa.minPlayers then
		fillTimers[modeId] = nil
	end
end

local function getQueueStatus(modeId)
	local queue = getQueue(modeId)
	local config = getModeConfig(modeId)
	local status = MatchState.QueueStatus.Waiting
	local fillRemaining

	if arenaBusy then
		status = MatchState.QueueStatus.Pending
	elseif modeId == "ffa" and fillTimers[modeId] then
		status = MatchState.QueueStatus.Filling
		fillRemaining = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		players = #queue,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = getQueueStatus(modeId)
	for _, player in getQueue(modeId) do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		if #getQueue(modeId) > 0 then
			broadcastQueueUpdate(modeId)
		end
	end
end

local function popQueue(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	fillTimers[modeId] = nil
	return picked
end

local function tryStartMatch(modeId)
	if arenaBusy or launching then
		return
	end

	local config = getModeConfig(modeId)
	local queue = getQueue(modeId)
	if #queue < config.minPlayers then
		return
	end

	if modeId == "ffa" and not fillTimers[modeId] then
		fillTimers[modeId] = { endsAt = os.clock() + config.fillTimeout }
		broadcastQueueUpdate(modeId)
		return
	end

	if modeId == "ffa" and fillTimers[modeId] and os.clock() < fillTimers[modeId].endsAt then
		return
	end

	local players = popQueue(modeId, config.maxPlayers)
	if #players < config.minPlayers then
		for _, player in players do
			table.insert(queue, player)
			playerQueue[player] = modeId
		end
		fillTimers[modeId] = nil
		return
	end

	launching = true
	fillTimers[modeId] = nil
	broadcastAllQueues()

	if onMatchReady then
		onMatchReady(players, modeId)
	end

	if Bindables.MatchReady then
		Bindables.MatchReady:Fire(players, modeId)
	end
end

local function evaluateQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.cancelLaunch(players, modeId)
	launching = false
	if typeof(players) == "table" and isValidMode(modeId) then
		local queue = getQueue(modeId)
		for _, player in players do
			if player.Parent and not playerQueue[player] then
				table.insert(queue, player)
				playerQueue[player] = modeId
			end
		end
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	launching = false
	broadcastAllQueues()
	if not busy then
		evaluateQueues()
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if playerQueue[player] == modeId then
		return true
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { players = 0 })
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.setOnMatchReady(callback)
	onMatchReady = callback
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not isValidMode(modeId) then
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

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId in MatchmakingConfig.MODES do
				if fillTimers[modeId] and os.clock() >= fillTimers[modeId].endsAt then
					tryStartMatch(modeId)
				end
			end
			broadcastAllQueues()
		end
	end)
end

return MatchmakingService
