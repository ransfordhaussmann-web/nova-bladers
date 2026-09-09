--[[
	MatchmakingService — per-mode queues with gather window before match start.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local queues = {}
local playerQueue = {}
local gatherTokens = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function playerInQueue(player)
	return playerQueue[player] ~= nil
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function findQueueIndex(modeId, player)
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function buildQueuePayload(modeId, forPlayer)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	local position = forPlayer and findQueueIndex(modeId, forPlayer) or nil

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = #names,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		players = names,
		position = position,
		inQueue = forPlayer ~= nil and position ~= nil,
		gathering = gatherTokens[modeId] ~= nil,
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId, nil)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			local personal = buildQueuePayload(modeId, queuedPlayer)
			Remotes.QueueUpdate:FireClient(queuedPlayer, personal)
		end
	end

	if callbacks.onQueueChanged then
		callbacks.onQueueChanged(modeId, payload)
	end
end

local function clearGather(modeId)
	gatherTokens[modeId] = nil
end

local function cancelGatherIfNeeded(modeId)
	local mode = getModeConfig(modeId)
	if getQueueSize(modeId) < mode.minPlayers then
		clearGather(modeId)
		broadcastQueue(modeId)
	end
end

local function popQueuePlayers(modeId)
	local queue = queues[modeId]
	local mode = getModeConfig(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(matchPlayers, player)
		end
	end

	return matchPlayers
end

local function startMatch(modeId)
	clearGather(modeId)
	local matchPlayers = popQueuePlayers(modeId)
	if #matchPlayers == 0 then
		return
	end

	for _, player in matchPlayers do
		if callbacks.onMatchReady then
			callbacks.onMatchReady(player, modeId)
		end
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = matchPlayers,
	})

	broadcastQueue(modeId)
end

local function scheduleGather(modeId)
	if gatherTokens[modeId] then
		return
	end

	local mode = getModeConfig(modeId)
	if getQueueSize(modeId) < mode.minPlayers then
		return
	end

	gatherTokens[modeId] = {}
	broadcastQueue(modeId)

	task.delay(MatchmakingConfig.GATHER_WINDOW, function()
		if not gatherTokens[modeId] then
			return
		end

		local currentMode = getModeConfig(modeId)
		if getQueueSize(modeId) < currentMode.minPlayers then
			clearGather(modeId)
			broadcastQueue(modeId)
			return
		end

		startMatch(modeId)
	end)
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	local index = findQueueIndex(modeId, player)
	if index then
		table.remove(queues[modeId], index)
	end
	playerQueue[player] = nil

	cancelGatherIfNeeded(modeId)
	broadcastQueue(modeId)

	if callbacks.onLeaveQueue then
		callbacks.onLeaveQueue(player)
	end

	Remotes.QueueUpdate:FireClient(player, {
		modeId = nil,
		inQueue = false,
		queued = 0,
		needed = 0,
		players = {},
	})

	return true
end

local MatchmakingService = {}

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.isInQueue(player)
	return playerInQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end

	if HubService.getPhase(player) == "arena" then
		return false, "in_match"
	end

	if playerInQueue(player) then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	local mode = getModeConfig(modeId)
	if getQueueSize(modeId) >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if callbacks.onJoinQueue then
		callbacks.onJoinQueue(player, modeId)
	end

	broadcastQueue(modeId)
	scheduleGather(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerInQueue(player) then
		return false
	end
	removeFromQueue(player)
	return true
end

function MatchmakingService.leaveAllQueues(player)
	return removeFromQueue(player)
end

function MatchmakingService.getActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.getActiveModeLabel()
	local mode = getModeConfig(MatchmakingService.getActiveModeId())
	return "Modus: " .. mode.label
end

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
end)

Remotes.JoinQueue.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getActiveModeId()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

return MatchmakingService
