--[[
	MatchmakingService — per-mode queues, FFA fill timer, MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerMode = {}
local remotes
local matchReadyBindable
local leaveHubForArena
local ffaFillDeadline = nil
local ffaFillToken = 0
local broadcastScheduled = false

local function getQueue(modeId)
	return queues[modeId] or {}
end

local function queueCount(modeId)
	return #getQueue(modeId)
end

local function removePlayerFromQueues(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if modeId == "ffa" and queueCount("ffa") < MatchModes.ffa.minPlayers then
		ffaFillDeadline = nil
		ffaFillToken += 1
	end
end

local function addPlayerToQueue(player, modeId)
	removePlayerFromQueues(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
end

local function getFfaSecondsLeft()
	if not ffaFillDeadline then
		return nil
	end
	return math.max(0, math.ceil(ffaFillDeadline - os.clock()))
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local count = queueCount(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queued = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = MatchStateService.isArenaBusy(),
		fillSecondsLeft = modeId == "ffa" and getFfaSecondsLeft(),
	}
end

local function broadcastQueueUpdates()
	broadcastScheduled = false
	for player, modeId in playerMode do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function scheduleBroadcast()
	if broadcastScheduled then
		return
	end
	broadcastScheduled = true
	task.delay(MatchmakingConfig.QUEUE_BROADCAST_DEBOUNCE, broadcastQueueUpdates)
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	for _, player in players do
		if leaveHubForArena then
			leaveHubForArena(player)
		end
	end
	matchReadyBindable:Fire({
		mode = modeId,
		players = players,
	})
	scheduleBroadcast()
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return false
	end
	if modeId == "ffa" and count < mode.maxPlayers and getFfaSecondsLeft() and getFfaSecondsLeft() > 0 then
		return false
	end
	return true
end

local function tryStartMode(modeId)
	if not canStartMode(modeId) then
		return false
	end
	if not MatchStateService.tryReserve() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local players = popPlayers(modeId, mode.maxPlayers)
	if #players < mode.minPlayers then
		MatchStateService.setArenaBusy(false)
		for index, player in players do
			table.insert(queues[modeId], index, player)
			playerMode[player] = modeId
		end
		return false
	end

	if modeId == "ffa" then
		ffaFillDeadline = nil
		ffaFillToken += 1
	end

	launchMatch(modeId, players)
	return true
end

local function tryStartAnyMode()
	for _, modeId in { "training", "pvp", "ffa" } do
		if tryStartMode(modeId) then
			return true
		end
	end
	return false
end

local function startFfaFillTimer()
	local mode = MatchModes.ffa
	if queueCount("ffa") < mode.minPlayers then
		return
	end
	if ffaFillDeadline then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	scheduleBroadcast()

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		ffaFillDeadline = nil
		tryStartMode("ffa")
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end
	if playerMode[player] == modeId then
		scheduleBroadcast()
		return
	end

	addPlayerToQueue(player, modeId)
	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))

	if modeId == "ffa" then
		local mode = MatchModes.ffa
		if queueCount("ffa") >= mode.maxPlayers then
			ffaFillDeadline = nil
			ffaFillToken += 1
			tryStartMode("ffa")
		else
			startFfaFillTimer()
			if not MatchStateService.isArenaBusy() then
				tryStartMode("ffa")
			end
		end
	else
		tryStartMode(modeId)
	end

	scheduleBroadcast()
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end
	removePlayerFromQueues(player)
	remotes.QueueUpdate:FireClient(player, { inQueue = false })
	scheduleBroadcast()
end

function MatchmakingService.init(options)
	remotes = options.remotes
	matchReadyBindable = options.matchReadyBindable
	leaveHubForArena = options.leaveHubForArena

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		tryStartAnyMode()
	end)
end

return MatchmakingService
