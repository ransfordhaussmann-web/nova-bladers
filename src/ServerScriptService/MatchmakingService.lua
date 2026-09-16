local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local pendingMatches = {}
local fillTimers = {}
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[entry.modeId] then
		fillTimers[entry.modeId] = nil
	end
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local pending = pendingMatches[entry.modeId]

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		position = table.find(queue, player) or 1,
		queueSize = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		pending = pending ~= nil,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function fireMatchReady(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
	end
	pendingMatches[modeId] = nil
	MatchReady:Fire(modeId, playerList)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if #queue > mode.maxPlayers then
		while #queue > mode.maxPlayers do
			table.remove(queue)
		end
	end

	local playerList = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(playerList, queue[i])
	end

	if MatchStateService.isArenaBusy() then
		pendingMatches[modeId] = playerList
		for _, player in playerList do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
			end
		end
		return
	end

	fireMatchReady(modeId, playerList)
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = true
	task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		if pendingMatches[modeId] then
			return
		end
		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

local function onArenaFreed()
	for modeId, playerList in pendingMatches do
		if not MatchStateService.isArenaBusy() then
			local valid = {}
			for _, player in playerList do
				if player.Parent then
					table.insert(valid, player)
				end
			end
			if #valid > 0 then
				fireMatchReady(modeId, valid)
				return
			end
			pendingMatches[modeId] = nil
		end
	end

	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false
	end

	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }
	broadcastQueueUpdate(modeId)

	if mode.instant or #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers then
		startFillTimer(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	broadcastQueueUpdate(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	return true
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.onArenaFreed()
	onArenaFreed()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local entry = playerQueue[player]
		if entry then
			removeFromQueue(player)
			broadcastQueueUpdate(entry.modeId)
		end

		for modeId, playerList in pendingMatches do
			for i, pendingPlayer in playerList do
				if pendingPlayer == player then
					table.remove(playerList, i)
					break
				end
			end
			if #playerList == 0 then
				pendingMatches[modeId] = nil
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_POLL_INTERVAL)
			if MatchStateService.isArenaBusy() then
				continue
			end
			if next(pendingMatches) ~= nil then
				onArenaFreed()
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
