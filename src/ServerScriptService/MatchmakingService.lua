local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local ffaFillToken = 0
local started = false

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function removeFromQueueList(queue, player)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			return true
		end
	end
	return false
end

local function removePlayerFromAllQueues(player)
	for _, queue in queues do
		removeFromQueueList(queue, player)
	end
	playerEntry[player] = nil
end

local function getQueueStatus(player)
	if MatchStateService.isArenaBusy() then
		return "pending"
	end
	return "waiting"
end

local function buildQueuePayload(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = queues[entry.modeId] or {}
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		status = entry.status,
		position = position,
		queueSize = #queue,
		required = mode and mode.maxPlayers or 1,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function sendQueueUpdate(player)
	if not isValidPlayer(player) then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
end

local function broadcastQueueUpdates()
	for player in playerEntry do
		if isValidPlayer(player) then
			sendQueueUpdate(player)
		end
	end
end

local function refreshQueueStatuses()
	for player, entry in playerEntry do
		if isValidPlayer(player) then
			entry.status = getQueueStatus(player)
		else
			removePlayerFromAllQueues(player)
		end
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if isValidPlayer(player) then
			table.insert(taken, player)
			playerEntry[player] = nil
		end
	end
	return taken
end

local function onMatchReady(players, modeId)
	MatchStateService.setArenaBusy(true)
	refreshQueueStatuses()
	broadcastQueueUpdates()
	MatchReady:Fire(players, modeId)
end

local function tryStartMode(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			onMatchReady(takePlayersFromQueue(modeId, mode.maxPlayers), modeId)
			return
		end
		if mode.preferredPlayers and #queue >= mode.preferredPlayers then
			onMatchReady(takePlayersFromQueue(modeId, #queue), modeId)
			return
		end
		return
	end

	onMatchReady(takePlayersFromQueue(modeId, mode.maxPlayers), modeId)
end

local function tryStartAllModes()
	for _, mode in MatchModes.all() do
		if mode.instantStart then
			tryStartMode(mode.id)
		end
	end
	tryStartMode("ffa")
end

local function scheduleFfaFillTimeout()
	ffaFillToken += 1
	local token = ffaFillToken
	local timeout = MatchmakingConfig.FFA_FILL_TIMEOUT

	task.delay(timeout, function()
		if token ~= ffaFillToken then
			return
		end
		if MatchStateService.isArenaBusy() then
			return
		end

		local queue = queues.ffa
		local mode = MatchModes.ffa
		if #queue >= mode.minPlayers then
			onMatchReady(takePlayersFromQueue("ffa", math.min(#queue, mode.maxPlayers)), "ffa")
		end
	end)
end

local function ensureFfaFillTimer()
	if #queues.ffa == 1 then
		scheduleFfaFillTimeout()
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false, "invalid_player"
	end

	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	removePlayerFromAllQueues(player)

	local status = getQueueStatus(player)
	playerEntry[player] = {
		modeId = modeId,
		status = status,
	}
	table.insert(queues[modeId], player)

	if modeId == "ffa" then
		ensureFfaFillTimer()
	end

	sendQueueUpdate(player)
	tryStartAllModes()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		sendQueueUpdate(player)
		return false
	end

	local modeId = playerEntry[player].modeId
	removePlayerFromAllQueues(player)

	if modeId == "ffa" and #queues.ffa == 0 then
		ffaFillToken += 1
	end

	sendQueueUpdate(player)
	return true
end

function MatchmakingService.joinAutoQueue(player)
	local count = #Players:GetPlayers()
	local modeId = "training"
	if count >= 3 then
		modeId = "ffa"
	elseif count == 2 then
		modeId = "pvp"
	end
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	refreshQueueStatuses()
	broadcastQueueUpdates()
	tryStartAllModes()
end

function MatchmakingService.onMatchStarted()
	MatchStateService.setArenaBusy(true)
	refreshQueueStatuses()
	broadcastQueueUpdates()
end

function MatchmakingService.getPlayerQueue(player)
	return buildQueuePayload(player)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" and modeId ~= "" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinAutoQueue(player)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromAllQueues(player)
		if #queues.ffa == 0 then
			ffaFillToken += 1
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for player in playerEntry do
				if isValidPlayer(player) then
					local entry = playerEntry[player]
					entry.status = getQueueStatus(player)
					sendQueueUpdate(player)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
