local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatches = {}
local getPhase
local leaveHubForArena

local function getMode(modeId)
	return MatchModes[modeId]
end

local function countQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	local count = 0
	for _ in pairs(queue) do
		count += 1
	end
	return count
end

local function getQueuePosition(modeId, player)
	local queue = queues[modeId]
	if not queue then
		return nil
	end
	local pos = 0
	for queuedPlayer in pairs(queue) do
		pos += 1
		if queuedPlayer == player then
			return pos
		end
	end
	return nil
end

local function buildQueuePayload(player, modeId, status)
	local mode = getMode(modeId)
	local total = countQueue(modeId)
	local position = getQueuePosition(modeId, player)
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = position,
		total = total,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status or "waiting",
	}
end

local function sendQueueUpdate(player, modeId, status)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
end

local function broadcastQueueUpdate(modeId)
	for queuedPlayer in pairs(queues[modeId] or {}) do
		sendQueueUpdate(queuedPlayer, modeId, "waiting")
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		queue[player] = nil
		if countQueue(modeId) == 0 then
			clearFillTimer(modeId)
		else
			broadcastQueueUpdate(modeId)
		end
	end
	playerQueue[player] = nil
end

local function collectReadyPlayers(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not queue or not mode then
		return nil
	end

	local ready = {}
	for queuedPlayer in pairs(queue) do
		if queuedPlayer.Parent and getPhase(queuedPlayer) == "hub" then
			table.insert(ready, queuedPlayer)
		end
	end

	table.sort(ready, function(a, b)
		return a.UserId < b.UserId
	end)

	if #ready < mode.minPlayers then
		return nil
	end

	local matchPlayers = {}
	for i = 1, math.min(#ready, mode.maxPlayers) do
		table.insert(matchPlayers, ready[i])
	end
	return matchPlayers
end

local function dequeuePlayers(modeId, matchPlayers)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, player in matchPlayers do
		queue[player] = nil
		playerQueue[player] = nil
	end
	clearFillTimer(modeId)
	broadcastQueueUpdate(modeId)
end

local function startMatch(modeId, matchPlayers)
	for _, player in matchPlayers do
		leaveHubForArena(player)
		sendQueueUpdate(player, modeId, "starting")
	end
	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(matchPlayers, modeId)
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode or countQueue(modeId) < mode.minPlayers then
		return false
	end

	local matchPlayers = collectReadyPlayers(modeId)
	if not matchPlayers then
		return false
	end

	if MatchStateService.isArenaBusy() then
		table.insert(pendingMatches, {
			modeId = modeId,
			players = matchPlayers,
		})
		for _, player in matchPlayers do
			sendQueueUpdate(player, modeId, "pending")
		end
		return false
	end

	dequeuePlayers(modeId, matchPlayers)
	startMatch(modeId, matchPlayers)
	return true
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token
	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function onPlayerJoinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		return false, "already_queued"
	end
	if getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	if not queues[modeId] then
		queues[modeId] = {}
	end

	queues[modeId][player] = true
	playerQueue[player] = modeId
	sendQueueUpdate(player, modeId, "waiting")
	broadcastQueueUpdate(modeId)

	local queued = countQueue(modeId)
	if mode.id == "training" then
		tryStartMatch(modeId)
	elseif queued >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif queued >= mode.minPlayers then
		scheduleFillTimer(modeId)
	end

	return true
end

function MatchmakingService.joinQueue(player, modeId)
	removeFromQueue(player)
	return onPlayerJoinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(options)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	getPhase = options.getPhase
	leaveHubForArena = options.leaveHubForArena

	for modeId in pairs(MatchModes) do
		queues[modeId] = {}
	end

	MatchStateService.onArenaFree(function()
		task.defer(function()
			if #pendingMatches > 0 then
				local nextMatch = table.remove(pendingMatches, 1)
				if nextMatch and nextMatch.players then
					local valid = {}
					for _, player in nextMatch.players do
						if player.Parent and getPhase(player) == "hub" then
							table.insert(valid, player)
						end
					end
					local mode = getMode(nextMatch.modeId)
					if mode and #valid >= mode.minPlayers then
						dequeuePlayers(nextMatch.modeId, valid)
						startMatch(nextMatch.modeId, valid)
						return
					end
				end
			end

			for modeId in pairs(MatchModes) do
				if tryStartMatch(modeId) then
					break
				end
			end
		end)
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		for i = #pendingMatches, 1, -1 do
			local match = pendingMatches[i]
			for _, queuedPlayer in match.players do
				if queuedPlayer == player then
					table.remove(pendingMatches, i)
					break
				end
			end
		end
	end)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
end

return MatchmakingService
