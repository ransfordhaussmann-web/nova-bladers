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
local callbacks = {}

for modeId in MatchModes do
	if typeof(MatchModes[modeId]) == "table" and MatchModes[modeId].id then
		queues[modeId] = {}
	end
end

local function getQueueCount(modeId)
	local count = 0
	for player in queues[modeId] do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function getQueuedPlayers(modeId)
	local list = {}
	for player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	local pending = MatchStateService.isArenaBusy()

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		status = pending and "pending" or "waiting",
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = {}
	for player in queues[modeId] do
		if player.Parent then
			payload[player] = buildQueuePayload(player)
		end
	end
	for player, data in payload do
		Remotes.QueueUpdate:FireClient(player, data)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	clearFillTimer(modeId)
	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	queues[modeId][player] = nil
	playerQueue[player] = nil

	if getQueueCount(modeId) < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return
	end

	if playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		return
	end

	removeFromQueue(player)

	local mode = MatchModes.get(modeId)
	if getQueueCount(modeId) >= mode.maxPlayers then
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			error = "Queue voll",
		})
		return
	end

	queues[modeId][player] = true
	playerQueue[player] = modeId

	local count = getQueueCount(modeId)
	if mode.fillTimeout and count >= mode.minPlayers and count < mode.maxPlayers then
		startFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.joinAuto(player)
	if callbacks.getRecommendedMode then
		MatchmakingService.joinQueue(player, callbacks.getRecommendedMode())
	else
		MatchmakingService.joinQueue(player, "training")
	end
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queued = getQueuedPlayers(modeId)
	local count = #queued

	if count < mode.minPlayers then
		return
	end

	if count > mode.maxPlayers then
		local trimmed = {}
		for i = 1, mode.maxPlayers do
			table.insert(trimmed, queued[i])
		end
		queued = trimmed
	elseif mode.fillTimeout and count < mode.maxPlayers and fillTimers[modeId] then
		return
	end

	clearFillTimer(modeId)
	MatchStateService.setMatchActive()

	for _, player in queued do
		removeFromQueue(player)
	end

	task.delay(MatchmakingConfig.START_DELAY, function()
		local active = {}
		for _, player in queued do
			if player.Parent then
				table.insert(active, player)
			end
		end

		if #active < mode.minPlayers then
			MatchStateService.setMatchEnded()
			for _, player in active do
				MatchmakingService.joinQueue(player, modeId)
			end
			return
		end

		if callbacks.onMatchStarting then
			callbacks.onMatchStarting(active, modeId)
		end

		Bindables.MatchReady:Fire(active, modeId)
	end)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setMatchEnded()
	task.defer(function()
		for modeId in queues do
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.init(opts)
	callbacks = opts or {}
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "auto" then
			MatchmakingService.joinAuto(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)
end

return MatchmakingService
