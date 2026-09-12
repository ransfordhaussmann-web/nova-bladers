local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerMode = {}
local fillTimers = {}
local fillStartedAt = {}
local started = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function getQueueSize(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	local count = 0
	for _k, _v in queue do
		count += 1
	end
	return count
end

local function getQueuePlayers(modeId)
	local queue = queues[modeId]
	if not queue then
		return {}
	end
	local list = {}
	for player in queue do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function getPlayerStatus(modeId)
	if GameMatchState.isBusy() then
		return MatchState.QueueStatus.Pending
	end
	return MatchState.QueueStatus.Waiting
end

local function buildUpdatePayload(modeId, player)
	local config = getModeConfig(modeId)
	if not config then
		return nil
	end

	local fillSecondsLeft
	local startedAt = fillStartedAt[modeId]
	if startedAt and config.fillTimeout > 0 then
		fillSecondsLeft = math.max(0, math.ceil(config.fillTimeout - (os.clock() - startedAt)))
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		status = getPlayerStatus(modeId),
		queued = getQueueSize(modeId),
		required = config.minPlayers,
		max = config.maxPlayers,
		fillSecondsLeft = fillSecondsLeft,
		inQueue = playerMode[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	local payload = buildUpdatePayload(modeId, nil)
	if not payload then
		return
	end

	for player, _ in queues[modeId] or {} do
		if player.Parent then
			local personal = buildUpdatePayload(modeId, player)
			Remotes.QueueUpdate:FireClient(player, personal)
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
	fillStartedAt[modeId] = nil
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	if not queue then
		return {}
	end

	local picked = {}
	for player, _ in queue do
		if player.Parent and #picked < count then
			table.insert(picked, player)
		end
	end

	for _, player in picked do
		queue[player] = nil
		playerMode[player] = nil
	end

	return picked
end

local function startMatch(modeId, players)
	clearFillTimer(modeId)
	GameMatchState.setBusy(true)

	for _, player in players do
		if HubService.enterMatchQueue then
			HubService.enterMatchQueue(player, modeId)
		end
	end

	broadcastAllQueues()
	Bindables.MatchReady:Fire(modeId, players)
end

local function tryStartMatch(modeId)
	if GameMatchState.isBusy() then
		return
	end

	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local size = getQueueSize(modeId)
	if size < config.minPlayers then
		return
	end

	if config.fillTimeout <= 0 then
		local players = popPlayers(modeId, config.maxPlayers)
		if #players >= config.minPlayers then
			startMatch(modeId, players)
		end
		return
	end

	if size >= config.maxPlayers then
		local players = popPlayers(modeId, config.maxPlayers)
		startMatch(modeId, players)
		return
	end

	if not fillTimers[modeId] then
		fillStartedAt[modeId] = os.clock()
		fillTimers[modeId] = task.delay(config.fillTimeout, function()
			fillTimers[modeId] = nil
			if GameMatchState.isBusy() then
				return
			end
			local currentSize = getQueueSize(modeId)
			if currentSize >= config.minPlayers then
				local players = popPlayers(modeId, config.maxPlayers)
				if #players >= config.minPlayers then
					startMatch(modeId, players)
				end
			else
				fillStartedAt[modeId] = nil
				broadcastQueue(modeId)
			end
		end)
	end
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		queue[player] = nil
	end
	playerMode[player] = nil

	if getQueueSize(modeId) < getModeConfig(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not started or not isValidMode(modeId) then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end
	if playerMode[player] == modeId then
		return true
	end

	removeFromQueue(player)
	queues[modeId][player] = true
	playerMode[player] = modeId

	if HubService.enterQueue then
		HubService.enterQueue(player, modeId)
	end

	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	local modeId = playerMode[player]
	removeFromQueue(player)

	if HubService.leaveQueue then
		HubService.leaveQueue(player)
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	return modeId
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	broadcastAllQueues()

	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = nil
		end
		if not modeId or not isValidMode(modeId) then
			local count = #Players:GetPlayers()
			if count >= 3 then
				modeId = "ffa"
			elseif count == 2 then
				modeId = "pvp"
			else
				modeId = "training"
			end
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	task.spawn(function()
		while started do
			for modeId in MatchmakingConfig.MODES do
				if getQueueSize(modeId) > 0 then
					broadcastQueue(modeId)
				end
			end
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
