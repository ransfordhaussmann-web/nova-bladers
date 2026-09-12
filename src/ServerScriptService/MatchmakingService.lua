local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchFlowState = require(script.Parent.MatchFlowState)

local Remotes, Bindables = RemotesSetup.ensure()

local queues = {}
local playerQueue = {}
local fillTokens = {}
local fillScheduled = {}

local callbacks = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getQueueStatus(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return nil
	end

	local queue = getQueue(modeId)
	local count = #queue
	local status = "waiting"

	if MatchFlowState.isArenaBusy() then
		status = "pending"
	elseif modeId == "training" and count >= 1 then
		status = "starting"
	elseif modeId == "pvp" and count >= mode.minPlayers then
		status = "starting"
	elseif modeId == "ffa" and count >= mode.minPlayers then
		status = "starting"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}
end

local function broadcastQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local payload = getQueueStatus(modeId)
	payload.inQueue = true
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function broadcastQueueToAll(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			broadcastQueueUpdate(player)
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillScheduled[modeId] = false
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	cancelFillTimer(modeId)
	broadcastQueueToAll(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })

	if callbacks.onLeaveQueue then
		callbacks.onLeaveQueue(player)
	end
end

local function collectReadyPlayers(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local ready = {}

	for i = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[i]
		if player.Parent then
			table.insert(ready, player)
		end
	end

	return ready
end

local function clearQueuePlayers(modeId, matched)
	local queue = getQueue(modeId)
	local matchedSet = {}
	for _, player in matched do
		matchedSet[player] = true
	end

	for i = #queue, 1, -1 do
		if matchedSet[queue[i]] then
			playerQueue[queue[i]] = nil
			table.remove(queue, i)
		end
	end

	cancelFillTimer(modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		broadcastQueueToAll(modeId)
		return
	end

	if MatchFlowState.isArenaBusy() then
		broadcastQueueToAll(modeId)
		return
	end

	local ready = collectReadyPlayers(modeId)
	if #ready < mode.minPlayers then
		return
	end

	clearQueuePlayers(modeId, ready)

	for _, player in ready do
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(ready, modeId)
	end

	Bindables.MatchReady:Fire(ready, modeId)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		tryStartMatch(modeId)
		return
	end

	if fillScheduled[modeId] then
		broadcastQueueToAll(modeId)
		return
	end

	fillScheduled[modeId] = true
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		fillScheduled[modeId] = false
		tryStartMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		broadcastQueueToAll(modeId)
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			tryStartMatch(modeId)
		else
			scheduleFillTimeout(modeId)
		end
	else
		tryStartMatch(modeId)
	end
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	if callbacks.onJoinQueue then
		callbacks.onJoinQueue(player, modeId)
	end

	broadcastQueueUpdate(player)
	broadcastQueueToAll(modeId)
	evaluateQueue(modeId)
end

local function onArenaFreed()
	for modeId in MatchmakingConfig.MODES do
		local queue = getQueue(modeId)
		if #queue > 0 then
			evaluateQueue(modeId)
		end
	end
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or modeId == "" then
		modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	removeFromQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
end)

Bindables.MatchEnded.Event:Connect(onArenaFreed)

local MatchmakingService = {}

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

print("[MatchmakingService] Queue system ready")

return MatchmakingService
