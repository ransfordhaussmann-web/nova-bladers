--[[
	MatchmakingService — per-mode queues, fill timeouts, and MatchReady dispatch.
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

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local pendingMatches = {}
local fillTimers = {}
local fillEndsAt = {}
local callbacks = {}

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function getQueueList(modeId)
	return queues[modeId]
end

local function removeFromQueueList(modeId, player)
	local list = queues[modeId]
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, i)
			return true
		end
	end
	return false
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
		fillEndsAt[modeId] = nil
	end
	return token
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local count = #list
	local position = 0
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	local fillRemaining = nil
	if fillEndsAt[modeId] and count >= (mode and mode.minPlayers or 1) then
		fillRemaining = math.max(0, math.ceil(fillEndsAt[modeId] - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		position = position,
		status = status,
		fillRemaining = fillRemaining,
		inQueue = position > 0,
	}
end

local function broadcastQueue(modeId)
	local list = getQueueList(modeId)
	for _, player in list do
		if isValidPlayer(player) then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	clearFillTimer(entry.modeId)
	removeFromQueueList(entry.modeId, player)
	playerQueue[player] = nil

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(entry.modeId)
end

local function canStartMatch(modeId, list)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local count = #list
	if count < mode.minPlayers then
		return false
	end

	if mode.instant then
		return count >= mode.maxPlayers
	end

	if count >= mode.maxPlayers then
		return true
	end

	return fillTimers[modeId] ~= nil and count >= mode.minPlayers
end

local function takePlayers(modeId)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local takeCount = math.min(#list, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, takeCount do
		local player = table.remove(list, 1)
		if isValidPlayer(player) then
			table.insert(matchPlayers, player)
			playerQueue[player] = nil
		end
	end

	clearFillTimer(modeId)
	broadcastQueue(modeId)
	return matchPlayers
end

local function dispatchMatch(modeId, matchPlayers)
	if #matchPlayers == 0 then
		return
	end

	if MatchStateService.isBusy() then
		table.insert(pendingMatches, {
			modeId = modeId,
			players = matchPlayers,
		})
		for _, player in matchPlayers do
			if isValidPlayer(player) then
				Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
			end
		end
		return
	end

	for _, player in matchPlayers do
		if isValidPlayer(player) then
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = false,
				status = "starting",
				modeId = modeId,
				modeLabel = MatchModes.get(modeId).label,
			})
		end
	end

	MatchReady:Fire(modeId, matchPlayers)
end

local function tryStartMatch(modeId)
	local list = getQueueList(modeId)
	if not canStartMatch(modeId, list) then
		return
	end

	local matchPlayers = takePlayers(modeId)
	dispatchMatch(modeId, matchPlayers)
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	local token = {}
	fillTimers[modeId] = token
	fillEndsAt[modeId] = os.clock() + mode.fillTimeout

	task.spawn(function()
		while fillTimers[modeId] == token and os.clock() < fillEndsAt[modeId] do
			broadcastQueue(modeId)
			task.wait(1)
		end

		if fillTimers[modeId] ~= token then
			return
		end

		fillTimers[modeId] = nil
		fillEndsAt[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if callbacks.getPlayerPhase and callbacks.getPlayerPhase(player) == "arena" then
		return
	end

	leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId }

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueue(modeId)

	if mode.instant then
		tryStartMatch(modeId)
	elseif #queues[modeId] >= mode.minPlayers then
		startFillTimer(modeId)
	end
end

local function resolveQuickMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function processPending()
	if MatchStateService.isBusy() or #pendingMatches == 0 then
		return
	end

	local nextMatch = table.remove(pendingMatches, 1)
	if nextMatch and #nextMatch.players > 0 then
		dispatchMatch(nextMatch.modeId, nextMatch.players)
	end
end

function MatchmakingService.init(opts)
	callbacks.getPlayerPhase = opts and opts.getPlayerPhase

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		if modeId == "quick" then
			modeId = resolveQuickMode()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
			processPending()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.onArenaFreed()
	broadcastAllQueues()
	processPending()
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

return MatchmakingService
