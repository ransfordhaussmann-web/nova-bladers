--[[
	MatchmakingService — per-mode queues on a single server.
	Starts matches via Bindables.StartMatch when enough players are waiting.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage.NovaBladers.MatchConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local initialized = false
local queues = {}
local playerQueue = {}
local gatherTokens = {}
local canStartMatch = function()
	return true
end
local onQueueChanged

for _, modeId in MatchConfig.MODE_ORDER do
	queues[modeId] = {}
	gatherTokens[modeId] = 0
end

local function getQueueSize(modeId)
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

local function buildQueueSnapshot(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchConfig.getMode(modeId)
	local index = findPlayerIndex(modeId, player)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = index,
		playersInQueue = getQueueSize(modeId),
		needed = mode and math.max(0, mode.minPlayers - getQueueSize(modeId)) or 0,
	}
end

local function broadcastQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueueSnapshot(player))
	end
end

local function broadcastModeQueue(modeId)
	for _, player in Players:GetPlayers() do
		if playerQueue[player] == modeId then
			broadcastQueueUpdate(player)
		end
	end
	if onQueueChanged then
		onQueueChanged(modeId, getQueueSize(modeId))
	end
end

local function popPlayers(modeId, count)
	local popped = {}
	for _ = 1, math.min(count, #queues[modeId]) do
		local player = table.remove(queues[modeId], 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(popped, player)
			broadcastQueueUpdate(player)
		end
	end
	return popped
end

local function startMatchForMode(modeId, players)
	if #players == 0 then
		return
	end
	if not canStartMatch() then
		for i = #players, 1, -1 do
			local player = players[i]
			table.insert(queues[modeId], 1, player)
			playerQueue[player] = modeId
			broadcastQueueUpdate(player)
		end
		return
	end

	Bindables.StartMatch:Fire(players, modeId)
end

local function scheduleGather(modeId)
	local mode = MatchConfig.getMode(modeId)
	if not mode or mode.gatherDelay <= 0 then
		local players = popPlayers(modeId, mode.maxPlayers)
		startMatchForMode(modeId, players)
		return
	end

	gatherTokens[modeId] += 1
	local token = gatherTokens[modeId]

	task.delay(mode.gatherDelay, function()
		if token ~= gatherTokens[modeId] then
			return
		end
		if getQueueSize(modeId) < mode.minPlayers then
			return
		end

		local players = popPlayers(modeId, mode.maxPlayers)
		startMatchForMode(modeId, players)
	end)
end

local function tryStartMatch(modeId)
	local mode = MatchConfig.getMode(modeId)
	if not mode then
		return
	end

	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	if mode.gatherDelay > 0 and size == mode.minPlayers then
		scheduleGather(modeId)
		return
	end

	if size >= mode.maxPlayers then
		gatherTokens[modeId] += 1
		local players = popPlayers(modeId, mode.maxPlayers)
		startMatchForMode(modeId, players)
		return
	end

	if mode.gatherDelay <= 0 and size >= mode.minPlayers then
		local players = popPlayers(modeId, mode.maxPlayers)
		startMatchForMode(modeId, players)
	end
end

function MatchmakingService.setCanStartMatch(callback)
	canStartMatch = callback
end

function MatchmakingService.setOnQueueChanged(callback)
	onQueueChanged = callback
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerQueue[player]
end

function MatchmakingService.getQueueSizes()
	local sizes = {}
	for _, modeId in MatchConfig.MODE_ORDER do
		sizes[modeId] = getQueueSize(modeId)
	end
	return sizes
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	local index = findPlayerIndex(modeId, player)
	if index then
		table.remove(queues[modeId], index)
	end
	playerQueue[player] = nil
	gatherTokens[modeId] += 1
	broadcastQueueUpdate(player)
	broadcastModeQueue(modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchConfig.isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] == modeId then
		return false, "already_queued"
	end
	if not canStartMatch() then
		return false, "match_active"
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(player)
	broadcastModeQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.joinQuickMatch(player)
	local bestMode = "training"
	local bestScore = -1

	for _, modeId in MatchConfig.MODE_ORDER do
		local mode = MatchConfig.getMode(modeId)
		local size = getQueueSize(modeId)
		local score = size
		if size + 1 >= mode.minPlayers then
			score += 100
		end
		if score > bestScore then
			bestScore = score
			bestMode = modeId
		end
	end

	return MatchmakingService.joinQueue(player, bestMode)
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()

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
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
