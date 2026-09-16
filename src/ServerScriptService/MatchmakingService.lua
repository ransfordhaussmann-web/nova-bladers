--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Bindables
local Remotes
local queues = {}
local playerMode = {}
local fillTimers = {}
local fillReady = {}
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function isPlayerValid(player)
	return player and player.Parent == Players
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
	if MatchStateService.isBusy() then
		status = "pending"
	elseif mode and #queue >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = position,
		total = #queue,
		required = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if isPlayerValid(player) then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
	fillReady[modeId] = false
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil

	if #queue == 0 then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if isPlayerValid(player) then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end
	clearFillTimer(modeId)
	return picked
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or MatchStateService.isBusy() then
		return false
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end
	if #queue >= mode.maxPlayers then
		return true
	end
	if modeId == "training" then
		return true
	end
	return fillReady[modeId] == true
end

local function tryStartMatch(modeId)
	if not canStartMode(modeId) then
		return
	end

	local mode = MatchModes.get(modeId)
	local count = math.min(#getQueue(modeId), mode.maxPlayers)
	local players = popPlayers(modeId, count)

	if #players == 0 then
		return
	end

	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = players,
	})

	for modeKey in MatchModes do
		if modeKey ~= modeId then
			broadcastQueueUpdate(modeKey)
		end
	end
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout or mode.fillTimeout <= 0 then
		return
	end
	if fillTimers[modeId] then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		fillReady[modeId] = true
		broadcastQueueUpdate(modeId)
		tryStartMatch(modeId)
	end)
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if not isPlayerValid(player) then
		return false, "invalid_player"
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue >= MatchModes.get(modeId).maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerMode[player] = modeId

	broadcastQueueUpdate(modeId)

	local mode = MatchModes.get(modeId)
	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif modeId == "training" then
		tryStartMatch(modeId)
	elseif #queue == mode.minPlayers then
		scheduleFillTimer(modeId)
	end

	return true
end

function MatchmakingService.joinQueue(player, modeId)
	return joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.removePlayer(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.onArenaFree()
	for modeId in MatchModes do
		local queue = getQueue(modeId)
		if #queue > 0 then
			broadcastQueueUpdate(modeId)
			local mode = MatchModes.get(modeId)
			if #queue >= mode.minPlayers then
				scheduleFillTimer(modeId)
			end
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	MatchStateService.onArenaFree(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.removePlayer(player)
	end)
end

return MatchmakingService
