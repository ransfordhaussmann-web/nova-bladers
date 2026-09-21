--[[
	MatchmakingService — per-mode queues, fill timeouts, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoinRemote = Remotes.QueueJoin
local QueueLeaveRemote = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local hubCallbacks = {}
local tickConnection = nil

local function initQueues()
	for modeId in MatchModes do
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
end

local function buildQueuePayload(modeId, status)
	local queue = queues[modeId]
	local mode = MatchModes[modeId]
	local secondsLeft = nil
	if queue.fillDeadline then
		secondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		modeId = modeId,
		label = mode.label,
		count = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		secondsLeft = secondsLeft,
		inQueue = true,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId, "waiting")
	for _, player in queues[modeId].players do
		if player.Parent then
			QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearPlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end
	playerQueue[player] = nil

	if #queue.players == 0 then
		queue.fillDeadline = nil
	end

	broadcastQueueUpdate(modeId)
end

local function canStartMatch(modeId)
	local queue = queues[modeId]
	local mode = MatchModes[modeId]
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if modeId == "training" then
		return count >= 1
	end

	if modeId == "pvp" then
		return count >= 2
	end

	if mode.fillTimeout and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return count >= mode.minPlayers
	end

	return false
end

local function takePlayersForMatch(modeId)
	local queue = queues[modeId]
	local mode = MatchModes[modeId]
	local count = math.min(#queue.players, mode.maxPlayers)

	local matchPlayers = {}
	for index = 1, count do
		table.insert(matchPlayers, queue.players[index])
	end

	for _ = 1, count do
		local player = table.remove(queue.players, 1)
		if player then
			playerQueue[player] = nil
		end
	end

	if #queue.players == 0 then
		queue.fillDeadline = nil
	end

	broadcastQueueUpdate(modeId)
	return matchPlayers
end

local function notifyPending(matchPlayers, modeId)
	local mode = MatchModes[modeId]
	for _, player in matchPlayers do
		if player.Parent then
			QueueUpdate:FireClient(player, {
				modeId = modeId,
				label = mode.label,
				count = #matchPlayers,
				minPlayers = mode.minPlayers,
				maxPlayers = mode.maxPlayers,
				status = "pending",
				inQueue = true,
			})
		end
	end
end

local function startMatch(modeId, matchPlayers)
	if hubCallbacks.leaveHubForArena then
		for _, player in matchPlayers do
			hubCallbacks.leaveHubForArena(player)
		end
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire({
		modeId = modeId,
		players = matchPlayers,
	})
end

local function tryLaunchMatch(modeId)
	if not canStartMatch(modeId) then
		return
	end

	local matchPlayers = takePlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = matchPlayers,
		}
		notifyPending(matchPlayers, modeId)
		return
	end

	startMatch(modeId, matchPlayers)
end

local function checkFillTimeouts()
	for modeId, mode in MatchModes do
		local queue = queues[modeId]
		if mode.fillTimeout and queue.fillDeadline and #queue.players >= mode.minPlayers then
			tryLaunchMatch(modeId)
		end
	end
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes[modeId] then
		return
	end

	if playerQueue[player] then
		clearPlayerFromQueue(player)
	end

	local queue = queues[modeId]
	local mode = MatchModes[modeId]
	if #queue.players >= mode.maxPlayers then
		return
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId

	if mode.fillTimeout and #queue.players >= mode.minPlayers and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + mode.fillTimeout
	end

	broadcastQueueUpdate(modeId)
	tryLaunchMatch(modeId)
end

local function leaveQueue(player)
	clearPlayerFromQueue(player)
	QueueUpdate:FireClient(player, { inQueue = false })
end

local function processPendingMatch()
	if not pendingMatch or MatchStateService.isArenaBusy() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	startMatch(match.modeId, match.players)
end

function MatchmakingService.getRecommendedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.init(callbacks)
	hubCallbacks = callbacks or {}
	initQueues()

	QueueJoinRemote.OnServerEvent:Connect(function(player, modeId)
		joinQueue(player, modeId)
	end)

	QueueLeaveRemote.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearPlayerFromQueue(player)
		if pendingMatch then
			for index, matchPlayer in pendingMatch.players do
				if matchPlayer == player then
					table.remove(pendingMatch.players, index)
					break
				end
			end
			if #pendingMatch.players == 0 then
				pendingMatch = nil
			end
		end
	end)

	MatchEnded.Event:Connect(function()
		processPendingMatch()
	end)

	MatchStateService.onArenaFreed(processPendingMatch)

	if tickConnection then
		tickConnection:Disconnect()
	end
	tickConnection = task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.TICK_INTERVAL)
			checkFillTimeouts()
		end
	end)
end

return MatchmakingService
