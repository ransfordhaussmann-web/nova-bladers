--[[
	MatchmakingService — Queue pro Modus, Fill-Timer für FFA, Pending bei belegter Arena.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local HubService

local queues = {}
local playerEntry = {}
local fillTokens = {}
local fillThreads = {}
local initialized = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= MatchmakingConfig.RECOMMENDED_THRESHOLDS.ffa then
		return "ffa"
	elseif count >= MatchmakingConfig.RECOMMENDED_THRESHOLDS.pvp then
		return "pvp"
	end
	return "training"
end

local function buildQueuePayload(player)
	local entry = playerEntry[player]
	if not entry then
		return {
			inQueue = false,
			arenaBusy = MatchStateService.isArenaBusy(),
			recommendedModeId = getRecommendedModeId(),
		}
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local fillSecondsLeft = nil
	local token = fillTokens[entry.modeId]
	if token and token.deadline then
		fillSecondsLeft = math.max(0, math.ceil(token.deadline - os.clock()))
	end

	local status = entry.status
	if status == "waiting" and #queue >= mode.minPlayers and mode.fillTimeout and fillSecondsLeft then
		status = "filling"
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		status = status,
		playersInQueue = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillSecondsLeft = fillSecondsLeft,
		arenaBusy = MatchStateService.isArenaBusy(),
		recommendedModeId = getRecommendedModeId(),
	}
end

local function broadcastQueueUpdate(targetPlayer)
	if not Remotes then
		return
	end

	if targetPlayer then
		Remotes.QueueUpdate:FireClient(targetPlayer, buildQueuePayload(targetPlayer))
		return
	end

	for player, _ in playerEntry do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = nil
	if fillThreads[modeId] then
		task.cancel(fillThreads[modeId])
		fillThreads[modeId] = nil
	end
end

local function pullPlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local pulled = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerEntry[player] = nil
			table.insert(pulled, player)
		end
	end
	return pulled
end

local function startMatchForMode(modeId)
	cancelFillTimer(modeId)

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	local playerList = pullPlayersFromQueue(modeId, #queue)
	if #playerList < mode.minPlayers then
		for _, player in playerList do
			playerEntry[player] = { modeId = modeId, status = "waiting" }
			table.insert(getQueue(modeId), player)
		end
		return
	end

	if MatchStateService.isArenaBusy() then
		for _, player in playerList do
			playerEntry[player] = { modeId = modeId, status = "pending" }
			table.insert(getQueue(modeId), player)
		end
		broadcastQueueUpdate()
		return
	end

	for _, player in playerList do
		if HubService and HubService.leaveHubForArena then
			HubService.leaveHubForArena(player)
		end
	end

	task.delay(MatchmakingConfig.MATCH_READY_DELAY, function()
		if Bindables and Bindables.MatchReady then
			Bindables.MatchReady:Fire(modeId, playerList)
		end
	end)

	broadcastQueueUpdate()
	MatchmakingService.evaluateAllQueues()
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		startMatchForMode(modeId)
		return
	end

	local token = { id = (fillTokens[modeId] and fillTokens[modeId].id or 0) + 1, deadline = os.clock() + mode.fillTimeout }
	fillTokens[modeId] = token

	if fillThreads[modeId] then
		task.cancel(fillThreads[modeId])
	end

	fillThreads[modeId] = task.delay(mode.fillTimeout, function()
		fillThreads[modeId] = nil
		if fillTokens[modeId] ~= token then
			return
		end
		fillTokens[modeId] = nil
		startMatchForMode(modeId)
	end)
end

function MatchmakingService.evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if #queue == 0 then
		cancelFillTimer(modeId)
		return
	end

	if #queue >= mode.maxPlayers then
		startMatchForMode(modeId)
		return
	end

	if mode.id == "training" and #queue >= 1 then
		startMatchForMode(modeId)
		return
	end

	if mode.id == "pvp" and #queue >= 2 then
		startMatchForMode(modeId)
		return
	end

	if mode.fillTimeout and #queue >= mode.minPlayers then
		if not fillTokens[modeId] then
			startFillTimer(modeId)
		end
		return
	end

	cancelFillTimer(modeId)
end

function MatchmakingService.evaluateAllQueues()
	for modeId, _ in MatchModes.all() do
		MatchmakingService.evaluateQueue(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getRecommendedModeId()
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	removeFromQueue(player)

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	end

	playerEntry[player] = { modeId = mode.id, status = status }
	table.insert(getQueue(mode.id), player)

	MatchmakingService.evaluateQueue(mode.id)
	broadcastQueueUpdate(player)
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end

	local modeId = playerEntry[player].modeId
	removeFromQueue(player)
	MatchmakingService.evaluateQueue(modeId)
	broadcastQueueUpdate(player)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.markIdle()
	task.defer(function()
		MatchmakingService.evaluateAllQueues()
		broadcastQueueUpdate()
	end)
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.isPlayerQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.init(hubServiceRef)
	if initialized then
		return
	end
	initialized = true

	HubService = hubServiceRef
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if Bindables.MatchEnded then
		Bindables.MatchEnded.Event:Connect(function()
			MatchmakingService.onMatchEnded()
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		if playerEntry[player] then
			local modeId = playerEntry[player].modeId
			removeFromQueue(player)
			MatchmakingService.evaluateQueue(modeId)
			broadcastQueueUpdate()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			if next(playerEntry) then
				broadcastQueueUpdate()
			end
		end
	end)
end

return MatchmakingService
