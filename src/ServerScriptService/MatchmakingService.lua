local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTokens = {}
local started = false

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

local function getQueueCount(modeId)
	return #(queues[modeId] or {})
end

local function buildQueuePayload(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	local count = getQueueCount(modeId)
	local arenaBusy = GameMatchState.isArenaOccupied()
	local status = "waiting"

	if arenaBusy then
		status = "pending"
	elseif mode and count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
		arenaBusy = arenaBusy,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId, nil)
	for _, queuedPlayer in queues[modeId] or {} do
		if queuedPlayer.Parent then
			local personal = buildQueuePayload(modeId, queuedPlayer)
			Remotes.QueueUpdate:FireClient(queuedPlayer, personal)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
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
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	broadcastQueueUpdate(modeId)
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 or GameMatchState.isArenaOccupied() then
		for _, player in playerList do
			if player.Parent and not playerQueue[player] then
				table.insert(queues[modeId], 1, player)
				playerQueue[player] = modeId
			end
		end
		return
	end

	for _, player in playerList do
		HubService.enterArenaForMatch(player)
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			status = "starting",
			inQueue = false,
		})
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMode(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or GameMatchState.isArenaOccupied() then
		return
	end

	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1

	if mode.fillTimeout > 0 and count < mode.maxPlayers then
		local token = fillTokens[modeId]
		task.delay(mode.fillTimeout, function()
			if token ~= fillTokens[modeId] or GameMatchState.isArenaOccupied() then
				return
			end
			if getQueueCount(modeId) < mode.minPlayers then
				return
			end

			local takeCount = math.min(getQueueCount(modeId), mode.maxPlayers)
			local players = popPlayers(modeId, takeCount)
			startMatch(modeId, players)
			broadcastQueueUpdate(modeId)
		end)
		return
	end

	local takeCount = math.min(count, mode.maxPlayers)
	local players = popPlayers(modeId, takeCount)
	startMatch(modeId, players)
	broadcastQueueUpdate(modeId)
end

local function tryStartAll()
	for modeId in queues do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.getMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if GameMatchState.isArenaOccupied() and playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		return
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = false,
		status = "left",
	})
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaOccupied(false)
	task.defer(tryStartAll)
	broadcastAllQueues()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
