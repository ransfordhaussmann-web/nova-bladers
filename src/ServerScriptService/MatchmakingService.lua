--[[
	MatchmakingService — per-mode queues with fill timeout and arena-busy pending state.
]]

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
local pendingRetryToken = 0
local callbacks = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function playerInList(list, player)
	for i, p in list do
		if p == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	local idx = playerInList(queue, player)
	if idx then
		table.remove(queue, idx)
	end
	playerQueue[player] = nil

	if fillTimers[modeId] then
		local mode = MatchModes.get(modeId)
		if mode and #queue < mode.minPlayers then
			fillTimers[modeId] = nil
		end
	end
end

local function buildPlayerList(modeId)
	local queue = getQueue(modeId)
	local list = {}
	for _, player in queue do
		if player.Parent then
			table.insert(list, {
				name = player.DisplayName,
				userId = player.UserId,
			})
		end
	end
	return list
end

local function getFillTimerRemaining(modeId)
	local timer = fillTimers[modeId]
	if not timer then
		return nil
	end
	return math.max(0, math.ceil(timer.endsAt - os.clock()))
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		players = buildPlayerList(modeId),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimer = getFillTimerRemaining(modeId),
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function sendQueueUpdate(player, modeId, status)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
	end
end

local function broadcastQueueUpdate(modeId, status)
	for _, player in getQueue(modeId) do
		sendQueueUpdate(player, modeId, status)
	end
end

local function clearQueue(modeId)
	queues[modeId] = {}
	fillTimers[modeId] = nil
end

local function leaveHubForPlayers(playerList)
	for _, player in playerList do
		if callbacks.leaveHubForArena then
			callbacks.leaveHubForArena(player)
		end
	end
end

local function startMatch(modeId, playerList)
	clearQueue(modeId)
	for _, player in playerList do
		playerQueue[player] = nil
	end

	MatchStateService.onMatchStarted()
	leaveHubForPlayers(playerList)
	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local valid = {}
	for _, player in queue do
		if player.Parent and playerQueue[player] == modeId then
			table.insert(valid, player)
		end
	end

	if #valid < mode.minPlayers then
		return
	end

	if #valid > mode.maxPlayers then
		local trimmed = {}
		for i = 1, mode.maxPlayers do
			trimmed[i] = valid[i]
		end
		valid = trimmed
	end

	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId, "pending")
		return
	end

	startMatch(modeId, valid)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local count = #queue

	if count >= mode.maxPlayers then
		fillTimers[modeId] = nil
		tryStartQueue(modeId)
		return
	end

	if count >= mode.minPlayers then
		if mode.fillTimeout and not fillTimers[modeId] then
			fillTimers[modeId] = {
				startedAt = os.clock(),
				endsAt = os.clock() + mode.fillTimeout,
			}
			task.delay(mode.fillTimeout, function()
				if fillTimers[modeId] then
					tryStartQueue(modeId)
				end
			end)
		elseif not mode.fillTimeout then
			tryStartQueue(modeId)
		else
			broadcastQueueUpdate(modeId, "waiting")
		end
	else
		fillTimers[modeId] = nil
		broadcastQueueUpdate(modeId, "waiting")
	end
end

local function resolveModeId(modeId)
	if modeId == "auto" or modeId == nil then
		return MatchModes.resolveAuto(#Players:GetPlayers())
	end
	if MatchModes.get(modeId) then
		return modeId
	end
	return MatchModes.resolveAuto(#Players:GetPlayers())
end

function MatchmakingService.joinQueue(player, modeId)
	if playerQueue[player] then
		return false, "already_queued"
	end

	if MatchStateService.isBusy() and callbacks.getPhase and callbacks.getPhase(player) == "arena" then
		return false, "in_match"
	end

	local resolvedId = resolveModeId(modeId)
	local queue = getQueue(resolvedId)
	table.insert(queue, player)
	playerQueue[player] = resolvedId

	local status = if MatchStateService.isBusy() then "pending" else "waiting"
	sendQueueUpdate(player, resolvedId, status)
	evaluateQueue(resolvedId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate(modeId, if MatchStateService.isBusy() then "pending" else "waiting")
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

local function retryPendingQueues()
	pendingRetryToken += 1
	local token = pendingRetryToken

	task.spawn(function()
		while token == pendingRetryToken do
			if not MatchStateService.isBusy() then
				for _, mode in MatchModes.all() do
					local queue = getQueue(mode.id)
					if #queue >= mode.minPlayers then
						tryStartQueue(mode.id)
					end
				end
			end
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
		end
	end)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.onMatchEnded()
	retryPendingQueues()
end

function MatchmakingService.init(opts)
	Remotes, Bindables = RemotesSetup.ensure()
	callbacks = opts or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerQueue[player] then
			MatchmakingService.leaveQueue(player)
		end
	end)

	retryPendingQueues()

	task.spawn(function()
		while true do
			for modeId, timer in fillTimers do
				if timer and #getQueue(modeId) >= (MatchModes.get(modeId) and MatchModes.get(modeId).minPlayers or 999) then
					broadcastQueueUpdate(modeId, if MatchStateService.isBusy() then "pending" else "waiting")
				end
			end
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
