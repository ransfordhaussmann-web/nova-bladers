local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = { players = {}, fillToken = 0 }
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for index, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, index)
				break
			end
		end
		queue.fillToken += 1
	end

	playerQueue[player] = nil
end

local function buildUpdatePayload(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local status = "waiting"

	if GameMatchState.isArenaBusy() then
		status = "arena_busy"
	elseif mode.fillTimeout > 0 and #queue.players >= mode.minPlayers then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildUpdatePayload(modeId)
	for _, player in queues[modeId].players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function clearMatchedPlayers(matchPlayers, modeId)
	for _, player in matchPlayers do
		removeFromQueue(player)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				status = "matched",
				modeId = modeId,
				modeLabel = MatchModes.get(modeId).label,
			})
		end
	end
end

local function launchMatch(matchPlayers, modeId)
	GameMatchState.setArenaBusy(true)
	clearMatchedPlayers(matchPlayers, modeId)
	Bindables.MatchReady:Fire(matchPlayers, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]

	if #queue.players < mode.minPlayers then
		return false
	end

	local matchPlayers = {}
	local count = math.min(#queue.players, mode.maxPlayers)
	for index = 1, count do
		table.insert(matchPlayers, queue.players[index])
	end

	if GameMatchState.isArenaBusy() then
		pendingMatch = { players = matchPlayers, mode = modeId }
		broadcastQueueUpdate(modeId)
		return false
	end

	launchMatch(matchPlayers, modeId)
	return true
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 then
		tryStartMatch(modeId)
		return
	end

	local queue = queues[modeId]
	queue.fillToken += 1
	local token = queue.fillToken

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		if #queue.players >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId

	local queue = queues[modeId]
	if #queue.players >= mode.maxPlayers then
		queue.fillToken += 1
		tryStartMatch(modeId)
	elseif #queue.players >= mode.minPlayers then
		if mode.fillTimeout > 0 then
			scheduleFillTimeout(modeId)
		else
			tryStartMatch(modeId)
		end
	end

	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { status = "left" })
	end
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaBusy(false)

	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil

		local stillValid = {}
		for _, player in match.players do
			if player.Parent then
				table.insert(stillValid, player)
			end
		end

		local mode = MatchModes.get(match.mode)
		if #stillValid >= mode.minPlayers then
			launchMatch(stillValid, match.mode)
			return
		end
	end

	for _, mode in MatchModes.all() do
		local queue = queues[mode.id]
		if #queue.players >= mode.minPlayers then
			if mode.fillTimeout > 0 then
				scheduleFillTimeout(mode.id)
			else
				tryStartMatch(mode.id)
			end
			break
		end
	end

	broadcastAllQueues()
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start()
	initQueues()

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

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
		local modeId = playerQueue[player]
		MatchmakingService.leaveQueue(player)

		if pendingMatch then
			for index, queuedPlayer in pendingMatch.players do
				if queuedPlayer == player then
					table.remove(pendingMatch.players, index)
					break
				end
			end
			local mode = MatchModes.get(pendingMatch.mode)
			if #pendingMatch.players < mode.minPlayers then
				pendingMatch = nil
			end
		end

		if modeId then
			broadcastQueueUpdate(modeId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId, queue in queues do
				if #queue.players > 0 then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
