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
local playerQueue = {}
local pendingStarts = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillToken = 0,
			fillThread = nil,
		}
	end
	return queues[modeId]
end

local function playerInList(list, player)
	for i, queued in list do
		if queued == player then
			return i
		end
	end
	return nil
end

local function buildQueuePayload(modeId, queue, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local count = #queue.players
	local pending = pendingStarts[modeId] == true or MatchStateService.isArenaBusy()
	local status = "waiting"
	if pending then
		status = "pending"
	elseif count >= mode.maxPlayers then
		status = "full"
	elseif count >= mode.minPlayers and mode.fillTimeout > 0 then
		status = "filling"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = playerInList(queue.players, player) ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, queue, player))
		end
	end
end

local function clearFillTimer(modeId)
	local queue = getQueue(modeId)
	queue.fillToken += 1
	queue.fillThread = nil
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	local index = playerInList(queue.players, player)
	if index then
		table.remove(queue.players, index)
	end
	playerQueue[player] = nil
	clearFillTimer(modeId)

	if not silent then
		broadcastQueueUpdate(modeId)
	end
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or #queue.players < mode.minPlayers then
		return false
	end

	if MatchStateService.isArenaBusy() then
		pendingStarts[modeId] = true
		broadcastQueueUpdate(modeId)
		return false
	end

	local roster = {}
	for i = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(roster, queue.players[i])
	end

	for _, player in roster do
		removeFromQueue(player, true)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = false,
				status = "matched",
			})
		end
	end

	pendingStarts[modeId] = nil
	clearFillTimer(modeId)
	MatchReady:Fire(roster, modeId)
	return true
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	clearFillTimer(modeId)
	queue.fillToken += 1
	local token = queue.fillToken

	queue.fillThread = task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		tryStartMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode then
		return
	end

	if #queue.players >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if #queue.players >= mode.minPlayers then
		if mode.fillTimeout <= 0 then
			tryStartMatch(modeId)
		elseif not queue.fillThread then
			scheduleFillTimer(modeId)
		end
	end

	broadcastQueueUpdate(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "unknown_mode"
	end

	if playerQueue[player] then
		removeFromQueue(player, true)
	end

	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	local modeId = playerQueue[player]
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, {
		modeId = modeId,
		inQueue = false,
		status = "left",
	})
	return true
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

function MatchmakingService.init(handlers)
	MatchStateService.onArenaIdle(function()
		for modeId in pairs(queues) do
			if pendingStarts[modeId] then
				pendingStarts[modeId] = nil
				evaluateQueue(modeId)
			end
		end
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if handlers.canJoinQueue and not handlers.canJoinQueue(player) then
			return
		end
		MatchmakingService.joinQueue(player, modeId or MatchmakingService.getRecommendedModeId())
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if handlers.onMatchReady then
		MatchReady.Event:Connect(function(roster, modeId)
			handlers.onMatchReady(roster, modeId)
		end)
	end
end

return MatchmakingService
