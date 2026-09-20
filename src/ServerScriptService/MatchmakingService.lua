local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil
local callbacks = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	local mode = MatchModes.get(modeId)
	if mode and #queue < mode.minPlayers then
		clearFillTimer(modeId)
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif #queue >= mode.maxPlayers then
		status = "full"
	elseif fillTimers[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		playerCount = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	local seen = {}
	for _, queuedPlayer in queue do
		seen[queuedPlayer] = true
		if queuedPlayer.Parent then
			local payload = buildQueuePayload(modeId, queuedPlayer)
			if payload then
				Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
			end
		end
	end

	for otherPlayer, otherModeId in playerQueue do
		if otherModeId == modeId and not seen[otherPlayer] and otherPlayer.Parent then
			local payload = buildQueuePayload(modeId, otherPlayer)
			if payload then
				Remotes.QueueUpdate:FireClient(otherPlayer, payload)
			end
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local ready = {}

	for _, queuedPlayer in queue do
		if queuedPlayer.Parent and callbacks.getPhase(queuedPlayer) ~= "arena" then
			table.insert(ready, queuedPlayer)
			if #ready >= mode.maxPlayers then
				break
			end
		end
	end

	return ready
end

local function finalizeQueue(modeId, readyPlayers)
	clearFillTimer(modeId)

	for _, player in readyPlayers do
		removeFromQueue(player)
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, readyPlayers)
	end

	broadcastAllQueues()
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local validCount = 0
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent and callbacks.getPhase(queuedPlayer) ~= "arena" then
			validCount += 1
		end
	end

	if validCount < mode.minPlayers then
		return
	end

	local readyPlayers = collectReadyPlayers(modeId)
	if #readyPlayers < mode.minPlayers then
		return
	end

	if #readyPlayers >= mode.maxPlayers then
		if MatchStateService.isArenaBusy() then
			pendingMatch = { modeId = modeId, players = readyPlayers }
			broadcastQueueUpdate(modeId)
			return
		end
		finalizeQueue(modeId, readyPlayers)
		return
	end

	if mode.fillTimeout and validCount >= mode.minPlayers then
		if not fillTimers[modeId] then
			fillTimers[modeId] = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				if MatchStateService.isArenaBusy() then
					local players = collectReadyPlayers(modeId)
					if #players >= mode.minPlayers then
						pendingMatch = { modeId = modeId, players = players }
						broadcastQueueUpdate(modeId)
					end
					return
				end
				local players = collectReadyPlayers(modeId)
				if #players >= mode.minPlayers then
					finalizeQueue(modeId, players)
				end
			end)
			broadcastQueueUpdate(modeId)
		end
		return
	end

	if not mode.fillTimeout and validCount >= mode.minPlayers then
		if MatchStateService.isArenaBusy() then
			pendingMatch = { modeId = modeId, players = readyPlayers }
			broadcastQueueUpdate(modeId)
			return
		end
		finalizeQueue(modeId, readyPlayers)
	end
end

local function processPendingMatch()
	if not pendingMatch or MatchStateService.isArenaBusy() then
		return
	end

	local modeId = pendingMatch.modeId
	local players = pendingMatch.players
	pendingMatch = nil

	local stillQueued = {}
	for _, player in players do
		if player.Parent and callbacks.getPhase(player) ~= "arena" then
			table.insert(stillQueued, player)
		end
	end

	local mode = MatchModes.get(modeId)
	if mode and #stillQueued >= mode.minPlayers then
		finalizeQueue(modeId, stillQueued)
	else
		broadcastAllQueues()
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		return false
	end
	if callbacks.getPhase(player) == "arena" then
		return false
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	if callbacks.onJoinQueue then
		callbacks.onJoinQueue(player, modeId)
	end

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)

	if callbacks.onLeaveQueue then
		callbacks.onLeaveQueue(player)
	end

	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(processPendingMatch)
	broadcastAllQueues()
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

function MatchmakingService.init(opts)
	Remotes, Bindables = RemotesSetup.ensure()
	callbacks = opts or {}

	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {}
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
