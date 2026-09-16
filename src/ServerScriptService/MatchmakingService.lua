--[[
	MatchmakingService — per-mode queues with fill timeouts and arena-pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTokens = {}
local remotes = nil
local matchReadyBindable = nil
local onPlayerLeaveHub = nil
local getDefaultModeId = nil

local QueueStatus = {
	Idle = "idle",
	Waiting = "waiting",
	Pending = "pending",
	Starting = "starting",
}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function isValidPlayer(player)
	return player and player.Parent == Players
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
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { status = QueueStatus.Idle }
	end

	local mode = getMode(entry.modeId)
	local queue = getQueue(entry.modeId)
	local count = #queue
	local pending = MatchStateService.isBusy() and count >= mode.minPlayers

	return {
		status = if pending then QueueStatus.Pending else QueueStatus.Waiting,
		modeId = entry.modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		playersNeeded = math.max(0, mode.minPlayers - count),
		maxPlayers = mode.maxPlayers,
		fillTimeout = entry.fillTimeoutRemaining,
	}
end

local function sendQueueUpdate(player)
	if not remotes or not isValidPlayer(player) then
		return
	end
	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
end

local function broadcastQueueUpdates(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		sendQueueUpdate(player)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	cancelFillTimer(modeId)
	local token = fillTokens[modeId]

	for _, player in getQueue(modeId) do
		local entry = playerQueue[player]
		if entry then
			entry.fillTimeoutRemaining = mode.fillTimeout
		end
	end
	broadcastQueueUpdates(modeId)

	task.spawn(function()
		local remaining = mode.fillTimeout
		while remaining > 0 do
			task.wait(1)
			if fillTokens[modeId] ~= token then
				return
			end

			remaining -= 1
			for _, player in getQueue(modeId) do
				local entry = playerQueue[player]
				if entry and entry.modeId == modeId then
					entry.fillTimeoutRemaining = remaining
				end
			end
			broadcastQueueUpdates(modeId)
		end

		if fillTokens[modeId] == token then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	for i = 1, math.min(count, #queue) do
		local player = queue[1]
		table.remove(queue, 1)
		if isValidPlayer(player) then
			table.insert(taken, player)
			playerQueue[player] = nil
		end
	end
	return taken
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	if MatchStateService.isBusy() then
		broadcastQueueUpdates(modeId)
		return false
	end

	cancelFillTimer(modeId)
	local playerCount = math.min(#queue, mode.maxPlayers)
	local players = takePlayersFromQueue(modeId, playerCount)

	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return false
	end

	for _, player in players do
		if onPlayerLeaveHub then
			onPlayerLeaveHub(player)
		end
		remotes.QueueUpdate:FireClient(player, {
			status = QueueStatus.Starting,
			modeId = modeId,
			modeLabel = mode.label,
			playersInQueue = #players,
		})
	end

	broadcastQueueUpdates(modeId)

	if matchReadyBindable then
		matchReadyBindable:Fire({
			players = players,
			mode = modeId,
		})
	end

	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false
	end

	local mode = getMode(modeId)
	if not mode then
		return false
	end

	MatchmakingService.leaveQueue(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false
	end

	table.insert(queue, player)
	playerQueue[player] = {
		modeId = modeId,
		fillTimeoutRemaining = nil,
	}

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)

	if #queue >= mode.minPlayers then
		if mode.fillTimeout > 0 and #queue < mode.maxPlayers then
			if not fillTokens[modeId] or playerQueue[queue[1]] and playerQueue[queue[1]].fillTimeoutRemaining == nil then
				startFillTimer(modeId)
			end
		else
			MatchmakingService.tryStartMatch(modeId)
		end
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player)
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)

	if getMode(modeId) and #getQueue(modeId) < getMode(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.getQueueStatus(player)
	return buildQueuePayload(player)
end

function MatchmakingService.start(config)
	remotes = config.remotes
	matchReadyBindable = config.matchReadyBindable
	onPlayerLeaveHub = config.onPlayerLeaveHub
	getDefaultModeId = config.getDefaultModeId

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId ~= nil and typeof(modeId) ~= "string" then
			return
		end
		local resolved = modeId
		if not resolved and getDefaultModeId then
			resolved = getDefaultModeId()
		end
		if not resolved then
			return
		end
		MatchmakingService.joinQueue(player, resolved)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onStateChanged(function(busy)
		if busy then
			return
		end
		for modeId, _ in MatchModes.all() do
			MatchmakingService.tryStartMatch(modeId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId, _ in MatchModes.all() do
				local mode = getMode(modeId)
				local queue = getQueue(modeId)
				if #queue >= mode.minPlayers and not MatchStateService.isBusy() then
					if mode.fillTimeout <= 0 or (playerQueue[queue[1]] and playerQueue[queue[1]].fillTimeoutRemaining == 0) then
						MatchmakingService.tryStartMatch(modeId)
					end
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
