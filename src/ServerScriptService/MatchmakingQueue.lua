--[[
	MatchmakingQueue — waits for players, picks mode by count, starts when ready.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local MatchmakingQueue = {}

local queue = {}
local queueStartedAt = nil
local heartbeat = nil
local onReadyCallback = nil
local broadcastCallback = nil

local function getModeForCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getModeLabel(mode)
	if mode == "ffa" then
		return "FFA"
	elseif mode == "pvp" then
		return "1v1 PvP"
	end
	return "Training"
end

local function findIndex(player)
	for i, queued in queue do
		if queued == player then
			return i
		end
	end
	return nil
end

local function buildStatus()
	local count = #queue
	local elapsed = queueStartedAt and (os.clock() - queueStartedAt) or 0
	local mode = getModeForCount(count)
	local maxWait = HubConfig.QUEUE_MAX_WAIT
	local minWait = HubConfig.QUEUE_MIN_WAIT

	local waitRemaining = math.max(0, maxWait - elapsed)
	if count >= HubConfig.QUEUE_MIN_FFA and elapsed >= minWait then
		waitRemaining = 0
	elseif count >= HubConfig.QUEUE_MIN_PVP and elapsed >= minWait then
		waitRemaining = 0
	end

	return {
		count = count,
		mode = mode,
		modeLabel = ("Modus: %s"):format(getModeLabel(mode)),
		waitRemaining = math.ceil(waitRemaining),
		searching = count > 0,
	}
end

local function broadcastStatus()
	if not broadcastCallback then
		return
	end
	local status = buildStatus()
	for _, player in queue do
		if player.Parent then
			local playerStatus = table.clone(status)
			playerStatus.position = findIndex(player) or 0
			playerStatus.inQueue = true
			broadcastCallback(player, playerStatus)
		end
	end
end

local function stopHeartbeat()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function startHeartbeat()
	if heartbeat then
		return
	end
	local lastBroadcast = 0
	heartbeat = RunService.Heartbeat:Connect(function()
		MatchmakingQueue.tryStartMatch()
		local now = os.clock()
		if now - lastBroadcast >= 1 then
			lastBroadcast = now
			broadcastStatus()
		end
	end)
end

function MatchmakingQueue.setOnReady(callback)
	onReadyCallback = callback
end

function MatchmakingQueue.setBroadcast(callback)
	broadcastCallback = callback
end

function MatchmakingQueue.join(player)
	if findIndex(player) then
		return
	end

	if #queue == 0 then
		queueStartedAt = os.clock()
		startHeartbeat()
	end

	table.insert(queue, player)
	broadcastStatus()
	MatchmakingQueue.tryStartMatch()
end

function MatchmakingQueue.leave(player)
	local index = findIndex(player)
	if not index then
		return false
	end

	table.remove(queue, index)
	if #queue == 0 then
		queueStartedAt = nil
		stopHeartbeat()
	end
	broadcastStatus()
	return true
end

function MatchmakingQueue.isQueued(player)
	return findIndex(player) ~= nil
end

function MatchmakingQueue.getStatusFor(player)
	local status = buildStatus()
	status.position = findIndex(player) or 0
	status.inQueue = findIndex(player) ~= nil
	return status
end

function MatchmakingQueue.tryStartMatch()
	if #queue == 0 or not queueStartedAt or not onReadyCallback then
		return
	end

	local elapsed = os.clock() - queueStartedAt
	local count = #queue
	local minWait = HubConfig.QUEUE_MIN_WAIT
	local maxWait = HubConfig.QUEUE_MAX_WAIT

	local shouldStart = false
	if count >= HubConfig.QUEUE_MIN_FFA and elapsed >= minWait then
		shouldStart = true
	elseif count >= HubConfig.QUEUE_MIN_PVP and elapsed >= minWait then
		shouldStart = true
	elseif count >= 1 and elapsed >= maxWait then
		shouldStart = true
	end

	if not shouldStart then
		return
	end

	local players = table.clone(queue)
	queue = {}
	queueStartedAt = nil
	stopHeartbeat()
	onReadyCallback(players)
end

return MatchmakingQueue
