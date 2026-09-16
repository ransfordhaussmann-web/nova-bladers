--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function countValidPlayers(queue)
	local count = 0
	for _, player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = countValidPlayers(queue)
	local position = 0
	for i, queued in queue do
		if queued == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif mode and count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = position,
		queueSize = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
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
		if token.cancelled then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil

	local mode = MatchModes.get(modeId)
	if mode and countValidPlayers(queue) < mode.minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local ready = {}

	for _, player in queue do
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(ready, player)
			if #ready >= mode.maxPlayers then
				break
			end
		end
	end

	if #ready < mode.minPlayers then
		return nil
	end

	return ready
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local readyPlayers = collectReadyPlayers(modeId)
	if not readyPlayers then
		return false
	end

	local queue = getQueue(modeId)
	for _, player in readyPlayers do
		for i, queued in queue do
			if queued == player then
				table.remove(queue, i)
				break
			end
		end
		playerMode[player] = nil
	end

	clearFillTimer(modeId)

	for _, player in readyPlayers do
		HubService.leaveHubForArena(player)
	end

	MatchReady:Fire(readyPlayers, modeId)
	broadcastAllQueues()
	return true
end

local function onQueueChanged(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = countValidPlayers(queue)

	broadcastQueueUpdate(modeId)

	if count >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif count >= mode.minPlayers then
		if mode.fillTimeout then
			startFillTimer(modeId)
		else
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	removeFromQueue(player)

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if countValidPlayers(queue) >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerMode[player] = modeId

	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return false
	end
	removeFromQueue(player)
	return true
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onArenaFree()
	MatchStateService.setArenaIdle()
	broadcastAllQueues()

	for modeId in queues do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
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
