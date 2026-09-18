--[[
	MatchmakingService — per-mode queues with fill timeout and arena-pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getQueueCount(modeId)
	return #ensureQueue(modeId)
end

local function buildUpdatePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local pending = not MatchStateService.isArenaFree()
	local status = pending and "pending" or "searching"
	local statusLabel = pending and MatchmakingConfig.PENDING_LABEL or MatchmakingConfig.SEARCHING_LABEL

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		statusLabel = statusLabel,
	}
end

local function broadcastQueue(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId))
		end
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	clearFillTimer(modeId)
	local token = fillTokens[modeId] or 0

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

local function takePlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	clearFillTimer(modeId)
	return taken
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	broadcastQueue(modeId)

	local mode = MatchModes.get(modeId)
	if #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers and mode.fillTimeout then
		if #queue == mode.minPlayers then
			startFillTimer(modeId)
		end
	elseif #queue >= mode.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if not MatchStateService.isArenaFree() then
		broadcastQueue(modeId)
		return
	end

	local playerCount = math.min(#queue, mode.maxPlayers)
	local players = takePlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(ensureQueue(modeId), player)
			playerQueue[player] = modeId
		end
		broadcastQueue(modeId)
		return
	end

	for _, player in players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
			HubService.leaveHubForArena(player)
		end
	end

	MatchReady:Fire(players, modeId)
end

function MatchmakingService.onArenaFreed()
	for _, mode in { MatchModes.training, MatchModes.pvp, MatchModes.ffa } do
		MatchmakingService.tryStartMatch(mode.id)
	end
end

function MatchmakingService.getSuggestedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init(remotes, bindables)
	Remotes = remotes
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getSuggestedModeId()
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
