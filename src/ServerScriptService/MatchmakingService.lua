--[[
	MatchmakingService — per-mode queues with FFA fill timeout and pending state
	when the arena is still in use.
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
local hubApi = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			pending = {},
		}
	end
	return queues[modeId]
end

local function listContains(list, player)
	for _, entry in list do
		if entry == player then
			return true
		end
	end
	return false
end

local function removeFromList(list, player)
	for i = #list, 1, -1 do
		if list[i] == player then
			table.remove(list, i)
		end
	end
end

local function getQueueCount(modeId)
	local queue = ensureQueue(modeId)
	return #queue.players + #queue.pending
end

local function buildUpdatePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players + #queue.pending
	local needed = mode.maxPlayers - count
	if needed < 0 then
		needed = 0
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		players = count,
		needed = needed,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}
end

local function sendQueueUpdate(player, modeId, status)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId, status))
	end
end

local function broadcastQueue(modeId)
	local queue = ensureQueue(modeId)
	local all = {}
	for _, player in queue.players do
		table.insert(all, player)
	end
	for _, player in queue.pending do
		table.insert(all, player)
	end

	for _, player in all do
		local status = listContains(queue.pending, player) ? "pending" : "searching"
		sendQueueUpdate(player, modeId, status)
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function takeReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local ready = {}

	for _, player in queue.players do
		if player.Parent and #ready < mode.maxPlayers then
			table.insert(ready, player)
		end
	end

	for _, player in ready do
		removeFromList(queue.players, player)
		playerQueue[player] = nil
	end

	clearFillTimer(modeId)
	return ready
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	local count = #queue.players
	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		for _, player in queue.players do
			if not listContains(queue.pending, player) then
				table.insert(queue.pending, player)
			end
		end
		broadcastQueue(modeId)
		return
	end

	if count > mode.maxPlayers then
		return
	end

	if modeId == "ffa" and count < mode.maxPlayers and fillTimers[modeId] then
		return
	end

	local ready = takeReadyPlayers(modeId)
	if #ready < mode.minPlayers then
		return
	end

	for _, player in ready do
		if hubApi.leaveHubForArena then
			hubApi.leaveHubForArena(player)
		end
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = ready,
	})
end

local function removePlayerFromAllQueues(player)
	local previousMode = playerQueue[player]
	playerQueue[player] = nil

	for modeId, queue in queues do
		removeFromList(queue.players, player)
		removeFromList(queue.pending, player)

		if #queue.players < MatchModes.get(modeId).minPlayers then
			clearFillTimer(modeId)
		end
	end

	if previousMode then
		broadcastQueue(previousMode)
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removePlayerFromAllQueues(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if hubApi.getPhase and hubApi.getPhase(player) ~= "hub" then
		return
	end

	removePlayerFromAllQueues(player)

	local queue = ensureQueue(modeId)
	local status

	if MatchStateService.isArenaBusy() then
		table.insert(queue.pending, player)
		status = "pending"
	else
		table.insert(queue.players, player)
		status = "searching"
	end

	playerQueue[player] = modeId
	sendQueueUpdate(player, modeId, status)
	broadcastQueue(modeId)

	if modeId == "ffa" and #queue.players >= mode.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId)
	end

	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.joinQuickMatch(player)
	local modeId = "training"
	if hubApi.getQuickModeId then
		modeId = hubApi.getQuickModeId()
	end
	MatchmakingService.joinQueue(player, modeId)
end

local function onArenaFreed()
	for modeId in queues do
		local queue = ensureQueue(modeId)
		for _, player in queue.pending do
			if player.Parent and not listContains(queue.players, player) then
				table.insert(queue.players, player)
			end
		end
		queue.pending = {}
		broadcastQueue(modeId)

		local mode = MatchModes.get(modeId)
		if modeId == "ffa" and #queue.players >= mode.minPlayers and not fillTimers[modeId] then
			startFillTimer(modeId)
		end

		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.init(api)
	Remotes, Bindables = RemotesSetup.ensure()
	hubApi = api or {}

	for _, mode in MatchModes.all() do
		ensureQueue(mode.id)
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinQuickMatch(player)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromAllQueues(player)
	end)

	MatchStateService.onArenaBusyChanged(function(busy)
		if not busy then
			task.defer(onArenaFreed)
		end
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchStateService.setArenaBusy(false)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
