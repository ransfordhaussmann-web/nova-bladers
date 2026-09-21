local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerToMode = {}
local pendingMatches = {}
local handlers = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillToken = 0,
			fillDeadline = nil,
		}
	end
	return queues[modeId]
end

local function clonePlayerList(list)
	local copy = {}
	for _, player in list do
		if player.Parent then
			table.insert(copy, player)
		end
	end
	return copy
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = 0
	for _, queuedPlayer in queue.players do
		if queuedPlayer.Parent then
			count += 1
		end
	end

	local fillTimeLeft
	if queue.fillDeadline then
		fillTimeLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		fillTimeLeft = fillTimeLeft,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload or { inQueue = false })
	end
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		if player.Parent and playerToMode[player] == modeId then
			local status = MatchStateService.isBusy() and "pending" or "waiting"
			sendQueueUpdate(player, buildQueuePayload(player, modeId, status))
		end
	end
end

local function clearQueue(modeId)
	local queue = getQueue(modeId)
	queue.fillToken += 1
	queue.fillDeadline = nil
	table.clear(queue.players)
end

local function removePlayerFromQueues(player)
	local modeId = playerToMode[player]
	if not modeId then
		return
	end

	playerToMode[player] = nil
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end

	local mode = MatchModes.get(modeId)
	if mode.fillTimeout and #queue.players < mode.minPlayers then
		queue.fillToken += 1
		queue.fillDeadline = nil
	end

	sendQueueUpdate(player, { inQueue = false })
	broadcastQueue(modeId)
end

local function canStart(modeId, queue)
	local mode = MatchModes.get(modeId)
	local players = clonePlayerList(queue.players)
	local count = #players

	if count < mode.minPlayers then
		return false, players
	end
	if count >= mode.maxPlayers then
		return true, players
	end
	if mode.minPlayers == mode.maxPlayers then
		return count >= mode.minPlayers, players
	end
	if mode.fillTimeout and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true, players
	end
	return false, players
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	local queue = getQueue(modeId)
	queue.fillToken += 1
	local token = queue.fillToken
	queue.fillDeadline = os.clock() + mode.fillTimeout

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)

	broadcastQueue(modeId)
end

local function launchMatch(modeId, players)
	MatchStateService.setActive(true)

	for _, player in players do
		playerToMode[player] = nil
		sendQueueUpdate(player, { inQueue = false })
	end
	clearQueue(modeId)

	if handlers.onMatchStarting then
		for _, player in players do
			handlers.onMatchStarting(player)
		end
	end

	Bindables.MatchReady:Fire(players, modeId)
end

function MatchmakingService.tryStartMatch(modeId)
	local queue = getQueue(modeId)
	local ready, players = canStart(modeId, queue)
	if not ready or #players == 0 then
		return
	end

	if MatchStateService.isBusy() then
		table.insert(pendingMatches, {
			modeId = modeId,
			players = players,
		})
		for _, player in players do
			sendQueueUpdate(player, buildQueuePayload(player, modeId, "pending"))
		end
		return
	end

	launchMatch(modeId, players)
end

local function onQueueChanged(modeId)
	local queue = getQueue(modeId)
	local mode = MatchModes.get(modeId)
	local count = #clonePlayerList(queue.players)

	if mode.id == "training" and count >= mode.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif mode.id == "pvp" and count >= mode.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif mode.id == "ffa" then
		if count >= mode.maxPlayers then
			MatchmakingService.tryStartMatch(modeId)
		elseif count >= mode.minPlayers and not queue.fillDeadline then
			scheduleFillTimer(modeId)
		end
	end

	broadcastQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		modeId = "training"
	end

	removePlayerFromQueues(player)

	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerToMode[player] = modeId

	sendQueueUpdate(player, buildQueuePayload(player, modeId, "waiting"))
	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	removePlayerFromQueues(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerToMode[player]
end

local function processPendingMatches()
	if MatchStateService.isBusy() then
		return
	end
	while #pendingMatches > 0 do
		local nextMatch = table.remove(pendingMatches, 1)
		local players = clonePlayerList(nextMatch.players)
		if #players > 0 then
			launchMatch(nextMatch.modeId, players)
			break
		end
	end
end

function MatchmakingService.init(newHandlers)
	handlers = newHandlers or {}

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onMatchEnded(function()
		processPendingMatches()
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchStateService.setActive(false)
		processPendingMatches()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			for modeId in queues do
				if #getQueue(modeId).players > 0 then
					broadcastQueue(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
