--[[
	MatchmakingService — per-mode queues, fill timeouts, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerQueue = {}
local fillTokens = {}
local pendingMatches = {}
local onMatchReadyCallback = nil
local initialized = false

function MatchmakingService.setOnMatchReady(callback)
	onMatchReadyCallback = callback
end

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

	playerQueue[player] = nil
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local arenaBusy = MatchStateService.isArenaBusy()

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		players = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = entry.status or "waiting",
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	cancelFillTimer(modeId)
	local token = fillTokens[modeId] or 0
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end

		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
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

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	cancelFillTimer(modeId)
	broadcastQueueUpdate(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = {
		modeId = modeId,
		status = "waiting",
	}

	broadcastQueueUpdate(modeId)

	if #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers then
		if mode.fillTimeout then
			startFillTimer(modeId)
		else
			MatchmakingService.tryStartMatch(modeId)
		end
	end

	return true
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	cancelFillTimer(modeId)

	local matchPlayers = {}
	local takeCount = math.min(#queue, mode.maxPlayers)
	for i = 1, takeCount do
		table.insert(matchPlayers, queue[i])
	end

	if MatchStateService.isArenaBusy() then
		for _, player in matchPlayers do
			removeFromQueue(player)
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				modeId = modeId,
				modeLabel = mode.label,
				players = #matchPlayers,
				minPlayers = mode.minPlayers,
				maxPlayers = mode.maxPlayers,
				status = "pending",
				arenaBusy = true,
			})
		end
		table.insert(pendingMatches, {
			modeId = modeId,
			players = matchPlayers,
		})
		broadcastQueueUpdate(modeId)
		return false
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
	end

	broadcastQueueUpdate(modeId)
	MatchStateService.setArenaBusy(true)
	if onMatchReadyCallback then
		onMatchReadyCallback(matchPlayers, modeId)
	end
	Bindables.MatchReady:Fire(matchPlayers, modeId)
	return true
end

local function processPendingMatches()
	if MatchStateService.isArenaBusy() then
		return
	end

	while #pendingMatches > 0 and not MatchStateService.isArenaBusy() do
		local pending = table.remove(pendingMatches, 1)
		local alivePlayers = {}
		for _, player in pending.players do
			if player.Parent then
				table.insert(alivePlayers, player)
			end
		end

		local mode = MatchModes.get(pending.modeId)
		if #alivePlayers == 0 then
			-- skip empty pending match
		elseif mode and #alivePlayers < mode.minPlayers then
			for _, player in alivePlayers do
				MatchmakingService.joinQueue(player, pending.modeId)
			end
		else
			for _, queuedPlayer in alivePlayers do
				Remotes.QueueUpdate:FireClient(queuedPlayer, { inQueue = false, status = "starting" })
			end
			MatchStateService.setArenaBusy(true)
			if onMatchReadyCallback then
				onMatchReadyCallback(alivePlayers, pending.modeId)
			end
			Bindables.MatchReady:Fire(alivePlayers, pending.modeId)
			break
		end
	end
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(processPendingMatches)
	broadcastAllQueues()
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)

		for i = #pendingMatches, 1, -1 do
			local pending = pendingMatches[i]
			for j = #pending.players, 1, -1 do
				if pending.players[j] == player then
					table.remove(pending.players, j)
				end
			end
			if #pending.players == 0 then
				table.remove(pendingMatches, i)
			end
		end
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
