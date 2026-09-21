--[[
	MatchmakingService — Queue pro Modus, startet Matches via MatchReady-Bindable.
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

	if fillTimers[entry.modeId] and #queue < MatchModes.get(entry.modeId).minPlayers then
		fillTimers[entry.modeId].cancelled = true
		fillTimers[entry.modeId] = nil
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return {
			status = MatchmakingConfig.STATUS.IDLE,
		}
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local pending = MatchStateService.isArenaBusy()

	return {
		status = pending and MatchmakingConfig.STATUS.PENDING or MatchmakingConfig.STATUS.QUEUED,
		modeId = entry.modeId,
		modeLabel = mode.label,
		position = table.find(queue, player) or #queue,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
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

local function leaveHubForQueuedPlayers(playerList)
	for _, player in playerList do
		if HubService.getPhase(player) == "hub" then
			HubService.leaveHubForArena(player)
		end
	end
end

local function startMatch(modeId, playerList)
	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		removeFromQueue(player)
	end

	for _, player in playerList do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				status = MatchmakingConfig.STATUS.STARTING,
				modeId = modeId,
			})
		end
	end

	leaveHubForQueuedPlayers(playerList)
	Bindables.MatchReady:Fire(modeId, playerList)
end

local function canStart(mode, queue)
	if #queue < mode.minPlayers then
		return false
	end
	if #queue >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout > 0 and fillTimers[mode.id] and fillTimers[mode.id].ready then
		return true
	end
	if mode.fillTimeout == 0 and #queue >= mode.minPlayers then
		return true
	end
	return false
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if not canStart(mode, queue) then
		return
	end

	local playerList = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[i]
		if player and player.Parent then
			table.insert(playerList, player)
		end
	end

	if #playerList < mode.minPlayers then
		return
	end

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end

	startMatch(modeId, playerList)
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers or #queue >= mode.maxPlayers then
		return
	end

	if fillTimers[modeId] and not fillTimers[modeId].cancelled then
		return
	end

	local token = { cancelled = false, ready = false }
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if token.cancelled or fillTimers[modeId] ~= token then
			return
		end
		token.ready = true
		tryStartMatch(modeId)
	end)
end

local function joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if HubService.getPhase(player) == "arena" then
		return false, "already_in_arena"
	end

	if playerQueue[player] then
		if playerQueue[player].modeId == modeId then
			return true
		end
		removeFromQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }

	broadcastQueueUpdate(modeId)
	scheduleFillTimer(modeId)
	tryStartMatch(modeId)

	return true
end

function MatchmakingService.joinQueue(player, modeId)
	return joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getSuggestedMode()
	local count = #Players:GetPlayers()
	return MatchModes.resolveFromPlayerCount(count).id
end

function MatchmakingService.onArenaFreed()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
		tryStartMatch(modeId)
	end
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getSuggestedMode()
		end
		local ok, reason = joinQueue(player, modeId)
		if not ok and reason then
			Remotes.QueueUpdate:FireClient(player, {
				status = MatchmakingConfig.STATUS.IDLE,
				error = reason,
			})
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaStateChanged(function(busy)
		if not busy then
			MatchmakingService.onArenaFreed()
		else
			for modeId in queues do
				broadcastQueueUpdate(modeId)
			end
		end
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchStateService.setArenaBusy(false)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
