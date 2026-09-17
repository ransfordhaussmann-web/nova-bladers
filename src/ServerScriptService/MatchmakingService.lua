--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTimers = {}
local pendingMatch = nil
local started = false

for _, modeId in MatchModes.ids() do
	queues[modeId] = {}
end

local function countValid(players)
	local valid = {}
	for _, player in players do
		if player.Parent and playerMode[player] then
			table.insert(valid, player)
		end
	end
	return valid
end

local function buildQueuePayload(player, modeId, pending)
	local mode = MatchModes.get(modeId)
	local queue = countValid(queues[modeId])
	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending == true,
		inQueue = true,
	}
end

local function sendQueueUpdate(player, modeId, pending)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, pending))
	end
end

local function broadcastQueue(modeId)
	local queue = countValid(queues[modeId])
	for _, player in queue do
		local isPending = pendingMatch
			and pendingMatch.modeId == modeId
			and table.find(pendingMatch.players, player) ~= nil
		sendQueueUpdate(player, modeId, isPending)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function removeFromAllQueues(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end
	playerMode[player] = nil
	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	clearFillTimer(modeId)
	broadcastQueue(modeId)
end

local function removePlayerFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end
	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	playerMode[player] = nil
end

local function takePlayers(modeId, count)
	local queue = countValid(queues[modeId])
	local taken = {}
	for i = 1, math.min(count, #queue) do
		local player = queue[1]
		table.remove(queue, 1)
		playerMode[player] = nil
		table.insert(taken, player)
	end
	return taken
end

local function takeSpecificPlayers(players)
	local taken = {}
	for _, player in players do
		if player.Parent and playerMode[player] then
			removePlayerFromQueue(player)
			table.insert(taken, player)
		end
	end
	return taken
end

local function dispatchMatch(modeId, players)
	clearFillTimer(modeId)
	pendingMatch = nil

	for _, player in players do
		removeFromAllQueues(player)
	end

	MatchReady:Fire({
		mode = modeId,
		players = players,
	})

	broadcastQueue(modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = countValid(queues[modeId])
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		local players = {}
		for i = 1, math.min(mode.maxPlayers, #queue) do
			table.insert(players, queue[i])
		end
		pendingMatch = { modeId = modeId, players = players }
		for _, player in players do
			sendQueueUpdate(player, modeId, true)
		end
		return
	end

	local count = math.min(mode.maxPlayers, #queue)
	local players = takePlayers(modeId, count)
	if #players >= mode.minPlayers then
		MatchStateService.setArenaBusy(true)
		dispatchMatch(modeId, players)
	end
end

local function scheduleFillTimer(modeId)
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
		tryStartMatch(modeId)
	end)
end

local function evaluateMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = countValid(queues[modeId])
	if #queue == 0 then
		clearFillTimer(modeId)
		return
	end

	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if #queue >= mode.minPlayers then
		if mode.fillTimeout then
			scheduleFillTimer(modeId)
		else
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end

	removeFromAllQueues(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	sendQueueUpdate(player, modeId, false)
	evaluateMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return false
	end
	removeFromAllQueues(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	return true
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromAllQueues(player)
	if pendingMatch then
		local idx = table.find(pendingMatch.players, player)
		if idx then
			table.remove(pendingMatch.players, idx)
			if #pendingMatch.players < MatchModes.get(pendingMatch.modeId).minPlayers then
				pendingMatch = nil
			end
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	MatchStateService.onArenaFreed(function()
		if pendingMatch then
			local modeId = pendingMatch.modeId
			local mode = MatchModes.get(modeId)
			local stillValid = {}
			for _, player in pendingMatch.players do
				if player.Parent and playerMode[player] == modeId then
					table.insert(stillValid, player)
				end
			end
			pendingMatch = nil

			if #stillValid >= mode.minPlayers and not MatchStateService.isArenaBusy() then
				local players = takeSpecificPlayers(stillValid)
				if #players >= mode.minPlayers then
					MatchStateService.setArenaBusy(true)
					dispatchMatch(modeId, players)
					return
				end
			end
		end

		for _, modeId in MatchModes.ids() do
			evaluateMode(modeId)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
