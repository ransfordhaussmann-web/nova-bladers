local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local ffaFillStartedAt = nil
local running = false
local onMatchReady

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil

	if modeId == "ffa" and (not queue or #queue < MatchModes.ffa.minPlayers) then
		ffaFillStartedAt = nil
	end
end

local function getQueueStatus(modeId, count)
	if MatchStateService.isArenaBusy() then
		return "pending"
	end
	local mode = getMode(modeId)
	if not mode then
		return "waiting"
	end
	if count >= mode.minPlayers then
		return "ready"
	end
	return "waiting"
end

local function buildUpdatePayload(player, modeId)
	local queue = ensureQueue(modeId)
	local mode = getMode(modeId)
	local count = #queue
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = position,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = getQueueStatus(modeId, count),
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId))
		end
	end
end

local function clearQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function popPlayers(modeId, amount)
	local queue = ensureQueue(modeId)
	local matched = {}
	for _ = 1, math.min(amount, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(matched, player)
		end
	end
	return matched
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	local count = #queue
	if count < mode.minPlayers then
		return
	end

	local shouldStart = false
	local takeCount = count

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			shouldStart = true
			takeCount = mode.maxPlayers
		elseif count >= mode.minPlayers then
			if not ffaFillStartedAt then
				ffaFillStartedAt = os.clock()
			end
			if os.clock() - ffaFillStartedAt >= MatchmakingConfig.FFA_FILL_TIMEOUT then
				shouldStart = true
				takeCount = count
			end
		end
	else
		shouldStart = count >= mode.minPlayers
		takeCount = mode.minPlayers
	end

	if not shouldStart then
		return
	end

	local matched = popPlayers(modeId, takeCount)
	if #matched < mode.minPlayers then
		for _, player in matched do
			table.insert(queue, player)
			playerQueue[player] = modeId
		end
		return
	end

	if modeId == "ffa" then
		ffaFillStartedAt = nil
	end

	if onMatchReady then
		onMatchReady(modeId, matched)
	end

	for _, player in matched do
		clearQueueUpdate(player)
	end

	broadcastQueueUpdate(modeId)
end

local function evaluateQueues()
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false
	end

	local mode = getMode(modeId)
	if not mode then
		return false
	end

	removeFromQueue(player)

	local queue = ensureQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	if modeId == "ffa" and #queue >= mode.minPlayers and not ffaFillStartedAt then
		ffaFillStartedAt = os.clock()
	end

	broadcastQueueUpdate(modeId)
	evaluateQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		clearQueueUpdate(player)
		return
	end

	removeFromQueue(player)
	clearQueueUpdate(player)
	if modeId then
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerQueue[player]
end

function MatchmakingService.start(callbacks)
	if running then
		return
	end
	running = true

	Remotes, Bindables = RemotesSetup.ensure()
	onMatchReady = callbacks.onMatchReady

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
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while running do
			evaluateQueues()
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
