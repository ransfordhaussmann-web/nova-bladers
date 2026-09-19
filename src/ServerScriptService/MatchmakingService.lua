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
local initialized = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
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

	if fillTimers[entry.modeId] then
		task.cancel(fillTimers[entry.modeId])
		fillTimers[entry.modeId] = nil
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
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
	elseif mode and #queue >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = position,
		queueSize = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in pairs(MatchModes.getAll()) do
		broadcastQueue(modeId)
	end
end

local function leaveHubForArena(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	HubService.leaveHubForArena(player)
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
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
	if #playerList == 0 then
		return
	end

	for _, player in playerList do
		leaveHubForArena(player)
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if #queue >= mode.maxPlayers then
		if fillTimers[modeId] then
			task.cancel(fillTimers[modeId])
			fillTimers[modeId] = nil
		end
		startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		return
	end

	if mode.fillTimeout and #queue >= mode.minPlayers and not fillTimers[modeId] then
		fillTimers[modeId] = task.delay(mode.fillTimeout, function()
			fillTimers[modeId] = nil
			if MatchStateService.isArenaBusy() then
				return
			end
			local currentQueue = getQueue(modeId)
			if #currentQueue >= mode.minPlayers then
				startMatch(modeId, popPlayers(modeId, #currentQueue))
			end
		end)
		broadcastQueue(modeId)
		return
	end

	if not mode.fillTimeout and #queue >= mode.minPlayers then
		startMatch(modeId, popPlayers(modeId, mode.minPlayers))
	end
end

local function tryStartAllModes()
	for modeId in pairs(MatchModes.getAll()) do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end

	if HubService.getPhase(player) == "arena" then
		return false
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = { modeId = modeId }

	broadcastAllQueues()
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if mode and mode.fillTimeout and fillTimers[modeId] and #queue < mode.minPlayers then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	broadcastQueue(modeId)
	return true
end

function MatchmakingService.getQueueInfo(player)
	local entry = playerQueue[player]
	if not entry then
		return nil
	end
	return buildQueuePayload(entry.modeId, player)
end

function MatchmakingService.onArenaFreed()
	broadcastAllQueues()
	tryStartAllModes()
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
