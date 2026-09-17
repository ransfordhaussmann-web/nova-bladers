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

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local started = false
local onMatchStart = nil

local function queueSize(modeId)
	return #queues[modeId]
end

local function findPlayerIndex(modeId, player)
	for i, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local index = findPlayerIndex(modeId, player)
	if index then
		table.remove(queues[modeId], index)
	end
	playerQueue[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local position = findPlayerIndex(entry.modeId, player) or 0
	local pending = MatchStateService.isArenaBusy()

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = queueSize(entry.modeId),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
	}
end

local function broadcastQueueUpdates()
	for player, _ in playerQueue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function popPlayers(modeId, count)
	local popped = {}
	for _ = 1, count do
		local player = table.remove(queues[modeId], 1)
		if not player then
			break
		end
		playerQueue[player] = nil
		table.insert(popped, player)
	end
	return popped
end

local function dispatchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	if onMatchStart then
		onMatchStart(modeId, playerList)
	end

	broadcastQueueUpdates()
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates()
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local size = queueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if size >= mode.maxPlayers then
			if fillTimers[modeId] then
				fillTimers[modeId].cancelled = true
				fillTimers[modeId] = nil
			end
			dispatchMatch(modeId, popPlayers(modeId, size))
			return
		end

		if size >= mode.minPlayers and not fillTimers[modeId] then
			local token = { cancelled = false }
			fillTimers[modeId] = token
			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if token.cancelled or fillTimers[modeId] ~= token then
					return
				end
				fillTimers[modeId] = nil
				if MatchStateService.isArenaBusy() then
					broadcastQueueUpdates()
					return
				end
				local currentSize = queueSize(modeId)
				if currentSize >= mode.minPlayers then
					dispatchMatch(modeId, popPlayers(modeId, currentSize))
				end
			end)
		end
		return
	end

	if size >= mode.maxPlayers then
		dispatchMatch(modeId, popPlayers(modeId, mode.maxPlayers))
	end
end

function MatchmakingService.setMatchStartHandler(handler)
	onMatchStart = handler
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
	broadcastQueueUpdates()
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false, "invalid_player"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	tryStartMatch(modeId)
	broadcastQueueUpdates()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdates()
	return true
end

function MatchmakingService.getQueueInfo(player)
	return buildQueuePayload(player)
end

function MatchmakingService.start(hubCallbacks)
	onMatchStart = function(modeId, playerList)
		for _, player in playerList do
			if player.Parent and hubCallbacks.leaveHubForArena then
				hubCallbacks.leaveHubForArena(player)
			end
		end
		Bindables.MatchReady:Fire(modeId, playerList)
	end

	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.recommendForPlayerCount(#Players:GetPlayers()).id
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		broadcastQueueUpdates()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
