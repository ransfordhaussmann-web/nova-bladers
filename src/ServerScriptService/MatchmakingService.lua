--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false
local onLeaveHub

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function countQueue(modeId)
	return #queues[modeId]
end

local function getQueuePlayers(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return {
			status = MatchmakingConfig.STATUS.IDLE,
			modeId = nil,
			modeLabel = nil,
			playersInQueue = 0,
			playersNeeded = 0,
			arenaBusy = not MatchStateService.isArenaFree(),
		}
	end

	local mode = MatchModes.get(entry.modeId)
	local queued = countQueue(entry.modeId)
	local needed = math.max(0, mode.minPlayers - queued)

	return {
		status = entry.status,
		modeId = entry.modeId,
		modeLabel = mode.label,
		playersInQueue = queued,
		playersNeeded = needed,
		fillSecondsLeft = entry.fillSecondsLeft,
		arenaBusy = not MatchStateService.isArenaFree(),
	}
end

local function broadcastQueue(modeId)
	local players = getQueuePlayers(modeId)
	for _, player in players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function broadcastAllQueues()
	for _, mode in MatchModes.all() do
		broadcastQueue(mode.id)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if countQueue(modeId) < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
		for _, queued in getQueuePlayers(modeId) do
			local queuedEntry = playerQueue[queued]
			if queuedEntry then
				queuedEntry.fillSecondsLeft = nil
				queuedEntry.status = MatchmakingConfig.STATUS.QUEUED
			end
		end
	end

	broadcastQueue(modeId)
end

local function setQueueStatus(modeId, status)
	for _, player in getQueuePlayers(modeId) do
		local entry = playerQueue[player]
		if entry then
			entry.status = status
		end
	end
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queued = countQueue(modeId)
	if queued < mode.minPlayers then
		return false
	end
	if queued > mode.maxPlayers then
		return false
	end
	if not MatchStateService.isArenaFree() then
		return false
	end
	return true
end

local function shouldWaitForFill(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return false
	end
	local queued = countQueue(modeId)
	return queued >= mode.minPlayers and queued < mode.maxPlayers and fillTimers[modeId] == nil
end

local function launchMatch(modeId)
	local mode = MatchModes.get(modeId)
	local players = getQueuePlayers(modeId)
	if #players < mode.minPlayers or #players > mode.maxPlayers then
		return
	end
	if not MatchStateService.isArenaFree() then
		setQueueStatus(modeId, MatchmakingConfig.STATUS.PENDING)
		broadcastQueue(modeId)
		return
	end

	clearFillTimer(modeId)
	setQueueStatus(modeId, MatchmakingConfig.STATUS.STARTING)
	broadcastQueue(modeId)

	local matchPlayers = {}
	for i = 1, math.min(#players, mode.maxPlayers) do
		table.insert(matchPlayers, players[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
		if onLeaveHub then
			onLeaveHub(player)
		end
	end

	MatchReady:Fire(matchPlayers, modeId)
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	local deadline = os.clock() + mode.fillTimeout
	for _, player in getQueuePlayers(modeId) do
		local entry = playerQueue[player]
		if entry then
			entry.fillSecondsLeft = mode.fillTimeout
			entry.status = MatchmakingConfig.STATUS.QUEUED
		end
	end
	broadcastQueue(modeId)

	fillTimers[modeId] = task.spawn(function()
		while os.clock() < deadline do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			local remaining = math.ceil(deadline - os.clock())
			for _, player in getQueuePlayers(modeId) do
				local entry = playerQueue[player]
				if entry then
					entry.fillSecondsLeft = math.max(0, remaining)
				end
			end
			broadcastQueue(modeId)

			if countQueue(modeId) >= mode.maxPlayers then
				break
			end
		end

		fillTimers[modeId] = nil
		for _, player in getQueuePlayers(modeId) do
			local entry = playerQueue[player]
			if entry then
				entry.fillSecondsLeft = nil
			end
		end

		if canStartMatch(modeId) then
			launchMatch(modeId)
		else
			broadcastQueue(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	if not MatchModes.isValid(modeId) then
		return
	end

	local mode = MatchModes.get(modeId)
	local queued = countQueue(modeId)

	if queued < mode.minPlayers then
		if not MatchStateService.isArenaFree() and queued > 0 then
			setQueueStatus(modeId, MatchmakingConfig.STATUS.PENDING)
		end
		broadcastQueue(modeId)
		return
	end

	if not MatchStateService.isArenaFree() then
		setQueueStatus(modeId, MatchmakingConfig.STATUS.PENDING)
		broadcastQueue(modeId)
		return
	end

	if mode.fillTimeout and queued < mode.maxPlayers then
		if shouldWaitForFill(modeId) then
			startFillTimer(modeId)
			return
		end
		if fillTimers[modeId] then
			return
		end
	end

	if canStartMatch(modeId) then
		launchMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = {
		modeId = modeId,
		status = MatchmakingConfig.STATUS.QUEUED,
		fillSecondsLeft = nil,
	}

	Remotes.QueueJoin:FireClient(player, buildQueuePayload(player))
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueLeave:FireClient(player)
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	for _, mode in MatchModes.all() do
		if countQueue(mode.id) > 0 then
			setQueueStatus(mode.id, MatchmakingConfig.STATUS.QUEUED)
			evaluateQueue(mode.id)
		end
	end
end

function MatchmakingService.start(options)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	onLeaveHub = options and options.onLeaveHub

	initQueues()

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
			if MatchStateService.isArenaFree() then
				for _, mode in MatchModes.all() do
					local entryStatus
					for _, player in getQueuePlayers(mode.id) do
						local entry = playerQueue[player]
						if entry and entry.status == MatchmakingConfig.STATUS.PENDING then
							entryStatus = true
							break
						end
					end
					if entryStatus then
						evaluateQueue(mode.id)
					end
				end
			else
				for _, mode in MatchModes.all() do
					if countQueue(mode.id) > 0 then
						setQueueStatus(mode.id, MatchmakingConfig.STATUS.PENDING)
						broadcastQueue(mode.id)
					end
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
