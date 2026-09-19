--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local callbacks = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromAllQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	if queue then
		for i = #queue, 1, -1 do
			if queue[i] == player then
				table.remove(queue, i)
			end
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function countValidPlayers(queue)
	local count = 0
	for i = #queue, 1, -1 do
		local player = queue[i]
		if not player.Parent then
			table.remove(queue, i)
		else
			count += 1
		end
	end
	return count
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local validCount = countValidPlayers(queue)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local timer = fillTimers[modeId]
	local fillRemaining = nil
	if timer and not timer.cancelled and timer.deadline then
		fillRemaining = math.max(0, math.ceil(timer.deadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		playersInQueue = validCount,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		position = position,
		arenaBusy = MatchStateService.isArenaBusy(),
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueueUpdate(player)
	if player.Parent and Remotes.QueueUpdate then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdatesForMode(modeId)
	local queue = getQueue(modeId)
	if not queue then
		return
	end
	for _, player in queue do
		broadcastQueueUpdate(player)
	end
end

local function pullPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or not queue then
		return {}
	end

	countValidPlayers(queue)
	local count = math.min(#queue, mode.maxPlayers)
	local pulled = {}
	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(pulled, player)
			playerQueue[player] = nil
		end
	end
	return pulled
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end

	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		if callbacks.onMatchStarting then
			callbacks.onMatchStarting(player, modeId)
		end
		broadcastQueueUpdate(player)
	end

	MatchReady:Fire({
		modeId = modeId,
		players = playerList,
	})
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or not queue then
		return false
	end

	local count = countValidPlayers(queue)
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "training" or modeId == "pvp" then
		return count >= mode.minPlayers
	end
	if modeId == "ffa" then
		local timer = fillTimers[modeId]
		if timer and timer.expired then
			return true
		end
	end
	return false
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end
	if not canStartMode(modeId) then
		return
	end

	local players = pullPlayersForMatch(modeId)
	if #players == 0 then
		return
	end

	startMatch(modeId, players)
end

local function tryStartAllMatches()
	for _, mode in MatchModes.getAll() do
		tryStartMatch(mode.id)
	end
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	local queue = getQueue(modeId)
	if not queue then
		return
	end

	local count = countValidPlayers(queue)
	if count < mode.minPlayers then
		return
	end

	if fillTimers[modeId] and not fillTimers[modeId].cancelled then
		return
	end

	local token = {
		cancelled = false,
		expired = false,
		deadline = os.clock() + mode.fillTimeout,
	}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if token.cancelled then
			return
		end
		token.expired = true
		tryStartMatch(modeId)
		broadcastQueueUpdatesForMode(modeId)
	end)
end

local function onQueueChanged(modeId)
	broadcastQueueUpdatesForMode(modeId)
	scheduleFillTimer(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false
	end
	if MatchStateService.isArenaBusy() and playerQueue[player] == modeId then
		-- Allow re-join refresh while waiting for arena
	elseif playerQueue[player] == modeId then
		broadcastQueueUpdate(player)
		return true
	end

	removeFromAllQueues(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	if callbacks.onJoinQueue then
		callbacks.onJoinQueue(player, modeId)
	end

	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	removeFromAllQueues(player)

	if callbacks.onLeaveQueue then
		callbacks.onLeaveQueue(player)
	end

	broadcastQueueUpdate(player)
	broadcastQueueUpdatesForMode(modeId)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(tryStartAllMatches)
end

function MatchmakingService.init(hubCallbacks)
	callbacks = hubCallbacks or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerQueue[player]
		if modeId then
			removeFromAllQueues(player)
			broadcastQueueUpdatesForMode(modeId)
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
