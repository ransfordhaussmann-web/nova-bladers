local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local pendingMatch = nil
local fillThreads = {}

local function getMode(modeId)
	return MatchModes.get(modeId) or MatchModes.training
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {}, fillReady = false }
	end
	return queues[modeId]
end

local function playerNames(playerList)
	local names = {}
	for _, queued in playerList do
		table.insert(names, queued.Name)
	end
	return names
end

local function buildQueuePayload(modeId, queue)
	local mode = getMode(modeId)
	local count = #queue.players
	local status = "waiting"

	if MatchStateService.isBusy() and count >= mode.minPlayers then
		status = "pending"
	elseif count >= mode.maxPlayers then
		status = "ready"
	elseif mode.fillTimeout > 0 and count >= mode.minPlayers then
		status = queue.fillReady and "ready" or "filling"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	return {
		mode = modeId,
		modeLabel = mode.label,
		players = playerNames(queue.players),
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = queue.fillSecondsLeft,
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	local payload = buildQueuePayload(modeId, queue)
	for _, player in queue.players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function stopFillTimer(modeId)
	if fillThreads[modeId] then
		task.cancel(fillThreads[modeId])
		fillThreads[modeId] = nil
	end
	local queue = queues[modeId]
	if queue then
		queue.fillSecondsLeft = nil
	end
end

local function extractPlayers(modeId, maxCount)
	local queue = queues[modeId]
	if not queue or #queue.players == 0 then
		return {}
	end

	local count = math.min(#queue.players, maxCount)
	local extracted = {}
	for i = 1, count do
		table.insert(extracted, queue.players[i])
	end
	for _ = 1, count do
		table.remove(queue.players, 1)
	end
	for _, queued in extracted do
		playerQueue[queued] = nil
	end

	queue.fillReady = false
	stopFillTimer(modeId)
	broadcastQueue(modeId)
	return extracted
end

local function launchMatch(modeId, matched)
	if #matched == 0 then
		return
	end

	if MatchStateService.isBusy() then
		pendingMatch = { modeId = modeId, players = matched }
		for _, player in matched do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					mode = modeId,
					modeLabel = getMode(modeId).label,
					players = playerNames(matched),
					count = #matched,
					minPlayers = getMode(modeId).minPlayers,
					maxPlayers = getMode(modeId).maxPlayers,
					status = "pending",
				})
			end
		end
		return
	end

	for _, player in matched do
		HubService.leaveHubForArena(player)
	end

	Bindables.MatchReady:Fire(matched, modeId)
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	stopFillTimer(modeId)
	local queue = ensureQueue(modeId)
	queue.fillSecondsLeft = mode.fillTimeout

	fillThreads[modeId] = task.spawn(function()
		while queue.fillSecondsLeft and queue.fillSecondsLeft > 0 do
			broadcastQueue(modeId)
			task.wait(MatchmakingConfig.FILL_TICK)
			if not queues[modeId] or #queue.players < mode.minPlayers then
				queue.fillReady = false
				stopFillTimer(modeId)
				return
			end
			queue.fillSecondsLeft -= MatchmakingConfig.FILL_TICK
		end

		queue.fillReady = true
		stopFillTimer(modeId)
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not queue or #queue.players < mode.minPlayers then
		return
	end

	if #queue.players >= mode.maxPlayers then
		launchMatch(modeId, extractPlayers(modeId, mode.maxPlayers))
		return
	end

	if mode.fillTimeout > 0 then
		if queue.fillReady then
			launchMatch(modeId, extractPlayers(modeId, mode.maxPlayers))
		elseif not fillThreads[modeId] then
			startFillTimer(modeId)
		end
		return
	end

	launchMatch(modeId, extractPlayers(modeId, mode.maxPlayers))
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, queued in queue.players do
			if queued == player then
				table.remove(queue.players, i)
				break
			end
		end
		if #queue.players < getMode(modeId).minPlayers then
			queue.fillReady = false
			stopFillTimer(modeId)
		end
	end
	playerQueue[player] = nil
	broadcastQueue(modeId)
end

local function onQueueChanged(modeId)
	broadcastQueue(modeId)
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.DEFAULT_MODE_ID
	end
	if not MatchModes.get(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE_ID
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	removeFromQueue(player)
	local queue = ensureQueue(modeId)
	queue.fillReady = false
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getActiveModeId()
	return MatchModes.getDefaultForPlayerCount(#Players:GetPlayers()).id
end

function MatchmakingService.onArenaIdle()
	if not pendingMatch or MatchStateService.isBusy() then
		return
	end

	local pending = pendingMatch
	pendingMatch = nil

	local valid = {}
	for _, player in pending.players do
		if player.Parent and HubService.getPhase(player) ~= "arena" then
			table.insert(valid, player)
		end
	end

	local mode = getMode(pending.modeId)
	if #valid < mode.minPlayers then
		for _, player in valid do
			MatchmakingService.joinQueue(player, pending.modeId)
		end
		return
	end

	for _, player in valid do
		HubService.leaveHubForArena(player)
	end
	Bindables.MatchReady:Fire(valid, pending.modeId)
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getActiveModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		if pendingMatch then
			for i, queued in pendingMatch.players do
				if queued == player then
					table.remove(pendingMatch.players, i)
					break
				end
			end
			if #pendingMatch.players < getMode(pendingMatch.modeId).minPlayers then
				pendingMatch = nil
			end
		end
	end)

	MatchStateService.onIdle(function()
		MatchmakingService.onArenaIdle()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
