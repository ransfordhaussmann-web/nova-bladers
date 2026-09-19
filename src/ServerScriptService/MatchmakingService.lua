local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local bindables
local onLeaveHub

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil
local tickConnection = nil

local function getMode(modeId)
	return MatchModes.get(modeId) or MatchModes.training
end

local function ensureQueue(modeId)
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

	local queue = ensureQueue(entry.modeId)
	for i, queuedPlayer in ipairs(queue) do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if #queue < getMode(entry.modeId).minPlayers then
		fillTimers[entry.modeId] = nil
	end

	playerQueue[player] = nil
end

local function getQueueCount(modeId)
	return #ensureQueue(modeId)
end

local function buildUpdatePayload(player, status)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = getMode(entry.modeId)
	local count = getQueueCount(entry.modeId)
	local fillLeft = nil

	local timerStart = fillTimers[entry.modeId]
	if timerStart and count >= mode.minPlayers and mode.fillTimeout then
		fillLeft = math.max(0, math.ceil(mode.fillTimeout - (os.clock() - timerStart)))
	end

	return {
		inQueue = true,
		modeId = mode.id,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or entry.status or "waiting",
		fillSecondsLeft = fillLeft,
	}
end

local function sendUpdate(player, status)
	if player.Parent and remotes.QueueUpdate then
		remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, status))
	end
end

local function broadcastQueueUpdate(modeId, status)
	for player, entry in playerQueue do
		if entry.modeId == modeId and player.Parent then
			sendUpdate(player, status)
		end
	end
end

local function canStartMode(modeId)
	local mode = getMode(modeId)
	local count = getQueueCount(modeId)

	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if not mode.fillTimeout then
		return count >= mode.minPlayers
	end

	local timerStart = fillTimers[modeId]
	if not timerStart then
		return false
	end

	return os.clock() - timerStart >= mode.fillTimeout
end

local function takePlayersFromQueue(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local players = {}

	for i = 1, count do
		local player = queue[1]
		table.remove(queue, 1)
		if player and player.Parent then
			table.insert(players, player)
			playerQueue[player] = nil
		end
	end

	fillTimers[modeId] = nil
	return players
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		return false
	end

	if not canStartMode(modeId) then
		return false
	end

	local players = takePlayersFromQueue(modeId)
	if #players == 0 then
		return false
	end

	pendingMatch = nil

	for _, player in players do
		if onLeaveHub then
			onLeaveHub(player)
		end
		sendUpdate(player, "starting")
	end

	if bindables.MatchReady then
		bindables.MatchReady:Fire({
			players = players,
			modeId = modeId,
		})
	end

	return true
end

local function checkQueues()
	for modeId in queues do
		local mode = getMode(modeId)
		local count = getQueueCount(modeId)

		if count >= mode.minPlayers and mode.fillTimeout and not fillTimers[modeId] then
			fillTimers[modeId] = os.clock()
			broadcastQueueUpdate(modeId)
		end

		if canStartMode(modeId) then
			if MatchStateService.isBusy() then
				pendingMatch = modeId
				broadcastQueueUpdate(modeId, "pending")
			else
				tryStartMatch(modeId)
			end
		end
	end
end

local function onMatchEnded()
	MatchStateService.setBusy(false)

	if pendingMatch and canStartMode(pendingMatch) then
		tryStartMatch(pendingMatch)
		return
	end

	pendingMatch = nil
	checkQueues()
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = ensureQueue(modeId)
	if #queue >= mode.maxPlayers then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = {
		modeId = modeId,
		status = "waiting",
		joinedAt = os.clock(),
	}

	if getQueueCount(modeId) >= mode.minPlayers and mode.fillTimeout then
		fillTimers[modeId] = os.clock()
	end

	sendUpdate(player, "waiting")
	checkQueues()
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	sendUpdate(player)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getQueueForPlayer(player)
	local entry = playerQueue[player]
	if not entry then
		return nil
	end
	return entry.modeId
end

function MatchmakingService.init(remotesFolder, bindablesFolder, callbacks)
	remotes = remotesFolder
	bindables = bindablesFolder
	onLeaveHub = callbacks and callbacks.onLeaveHub

	if bindables.MatchEnded then
		bindables.MatchEnded.Event:Connect(onMatchEnded)
	end

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if not tickConnection then
		tickConnection = task.spawn(function()
			while true do
				task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
				checkQueues()
			end
		end)
	end

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
