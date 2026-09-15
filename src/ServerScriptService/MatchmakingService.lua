--[[
	MatchmakingService — per-mode queues, fill timeouts, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function initQueues()
	for _, modeId in MatchModes.getIds() do
		queues[modeId] = {}
	end
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		local mode = MatchModes.get(modeId)
		if mode and mode.fillTimeout and getQueueSize(modeId) < mode.minPlayers then
			fillTimers[modeId].cancelled = true
			fillTimers[modeId] = nil
		end
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeout = mode.fillTimeout,
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	broadcastAllQueues()
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	local limit = math.min(count or #queue, #queue)
	for _ = 1, limit do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerQueue[nextPlayer] = nil
			table.insert(taken, nextPlayer)
		end
	end
	return taken
end

local function launchMatch(modeId, playerList)
	for _, player in playerList do
		if HubService.leaveHubForArena then
			HubService.leaveHubForArena(player)
		end
	end

	MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})

	broadcastAllQueues()
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return false
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end

	local playerList = takePlayers(modeId, mode.maxPlayers)
	if #playerList < mode.minPlayers then
		for i = #playerList, 1, -1 do
			table.insert(queue, 1, playerList[i])
			playerQueue[playerList[i]] = { modeId = modeId }
		end
		return false
	end

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end

	MatchStateService.setArenaBusy(true)
	launchMatch(modeId, playerList)
	return true
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = { cancelled = false }
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if token.cancelled or fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil

		if getQueueSize(modeId) >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	if playerQueue[player] then
		if playerQueue[player].modeId == modeId then
			return
		end
		leaveQueue(player)
	end

	local queue = queues[modeId]
	if #queue >= mode.maxPlayers then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }

	local payload = buildQueuePayload(modeId, player)
	Remotes.QueueUpdate:FireClient(player, payload)
	broadcastQueue(modeId)

	if mode.id == "training" or #queue >= mode.minPlayers then
		tryStartMatch(modeId)
	elseif mode.fillTimeout then
		scheduleFillTimeout(modeId)
	end
end

local function onArenaFreed()
	for modeId in queues do
		if getQueueSize(modeId) > 0 then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.start(remotes, bindables)
	if started then
		return
	end
	started = true

	Remotes = remotes
	Bindables = bindables
	MatchReady = bindables.MatchReady

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		broadcastAllQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
			if MatchStateService.isArenaBusy() then
				continue
			end
			for modeId in queues do
				if getQueueSize(modeId) > 0 then
					tryStartMatch(modeId)
				end
			end
		end
	end)
end

function MatchmakingService.notifyArenaBusy()
	MatchStateService.setArenaBusy(true)
	broadcastAllQueues()
end

function MatchmakingService.notifyArenaFree()
	MatchStateService.setArenaBusy(false)
	onArenaFreed()
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.getSuggestedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
