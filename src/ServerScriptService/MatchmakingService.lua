--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local fillTokens = {}

for _, mode in MatchModes.all() do
	queues[mode.id] = {}
	fillTokens[mode.id] = 0
end

local function getQueueSize(modeId)
	local count = 0
	for player in queues[modeId] do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function getModeDef(modeId)
	return MatchModes.get(modeId)
end

local function buildQueuePayload(modeId, player)
	local mode = getModeDef(modeId)
	if not mode then
		return nil
	end

	local entry = playerEntry[player]
	local size = getQueueSize(modeId)
	local pending = MatchStateService.isBusy()

	return {
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = size,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending and entry ~= nil,
		inQueue = entry ~= nil and entry.modeId == modeId,
	}
end

local function broadcastQueue(modeId)
	local mode = getModeDef(modeId)
	if not mode then
		return
	end

	for player in queues[modeId] do
		if player.Parent and HubService.getPhase(player) == "hub" then
			QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	playerEntry[player] = nil
	queues[modeId][player] = nil
	broadcastQueue(modeId)
end

local function collectReadyPlayers(modeId, count)
	local mode = getModeDef(modeId)
	local ready = {}
	for player in queues[modeId] do
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(ready, player)
			if #ready >= count or #ready >= mode.maxPlayers then
				break
			end
		end
	end
	return ready
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 or MatchStateService.isBusy() then
		return
	end

	fillTokens[modeId] += 1
	MatchStateService.setBusy()

	for _, player in playerList do
		removeFromQueue(player)
		HubService.leaveForArena(player)
	end

	MatchReady:Fire(playerList, modeId)
	broadcastAllQueues()
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = getModeDef(modeId)
	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		broadcastQueue(modeId)
		return
	end

	if modeId == "ffa" and size < mode.maxPlayers then
		fillTokens[modeId] += 1
		local token = fillTokens[modeId]
		broadcastQueue(modeId)

		task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
			if token ~= fillTokens[modeId] or MatchStateService.isBusy() then
				return
			end

			local ready = collectReadyPlayers(modeId, mode.maxPlayers)
			if #ready >= mode.minPlayers then
				launchMatch(modeId, ready)
			end
		end)
		return
	end

	local takeCount = mode.maxPlayers
	if modeId == "training" then
		takeCount = 1
	elseif modeId == "pvp" then
		takeCount = 2
	end

	local ready = collectReadyPlayers(modeId, takeCount)
	if #ready >= mode.minPlayers then
		launchMatch(modeId, ready)
	end
end

local function onArenaFreed()
	broadcastAllQueues()
	for modeId in queues do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeDef(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)
	queues[modeId][player] = true
	playerEntry[player] = { modeId = modeId }
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init()
	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchStateService.setIdle()
		task.defer(onArenaFreed)
	end)
end

return MatchmakingService
