--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local fillEndsAt = {}
local getRecommendedModeId

local function initQueues()
	for _, modeId in MatchModes.all() do
		queues[modeId] = {}
	end
end

local function getQueueSize(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	local count = 0
	for _, player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local nextQueue = {}
	for _, player in queue do
		if player.Parent and playerQueue[player] == modeId then
			table.insert(nextQueue, player)
		end
	end
	queues[modeId] = nextQueue
end

local function resolveAutoModeId()
	if getRecommendedModeId then
		local recommended = getRecommendedModeId()
		if MatchModes.isValid(recommended) then
			return recommended
		end
	end

	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function resolveModeId(modeId)
	if modeId == "auto" or modeId == MatchmakingConfig.PORTAL_MODE then
		return resolveAutoModeId()
	end
	if MatchModes.isValid(modeId) then
		return modeId
	end
	return nil
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local size = getQueueSize(modeId)
	local status = "queued"
	local message = MatchmakingConfig.UI.QUEUED

	if not MatchStateService.isArenaAvailable() then
		status = "pending"
		message = MatchmakingConfig.UI.PENDING
	end

	local fillRemaining = nil
	if fillEndsAt[modeId] then
		fillRemaining = math.max(0, math.ceil(fillEndsAt[modeId] - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		queueSize = size,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
		message = message,
		fillRemaining = fillRemaining,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	local payload = buildQueuePayload(player, modeId)
	payload.inQueue = true
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function broadcastQueueUpdate(modeId)
	pruneQueue(modeId)
	for _, player in queues[modeId] do
		sendQueueUpdate(player)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillEndsAt[modeId] = nil
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	pruneQueue(modeId)

	if getQueueSize(modeId) == 0 then
		cancelFillTimer(modeId)
	end

	if not silent then
		broadcastQueueUpdate(modeId)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end
	if not MatchStateService.isArenaAvailable() then
		return false
	end
	return getQueueSize(modeId) >= mode.minPlayers
end

local function popPlayersForMatch(modeId)
	pruneQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local takeCount = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}
	for i = 1, takeCount do
		table.insert(matchPlayers, queue[i])
	end

	queues[modeId] = {}
	cancelFillTimer(modeId)

	for _, player in matchPlayers do
		playerQueue[player] = nil
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				status = "ready",
				message = MatchmakingConfig.UI.READY,
				modeId = modeId,
				modeLabel = mode.label,
			})
		end
	end

	return matchPlayers
end

local function startMatch(modeId)
	if not canStartMode(modeId) then
		return false
	end

	local players = popPlayersForMatch(modeId)
	if #players == 0 then
		return false
	end

	MatchStateService.setArenaBusy(true)
	for _, player in players do
		if HubService.getPhase(player) ~= "arena" then
			HubService.leaveHubForArena(player)
		end
	end

	MatchReady:Fire({
		mode = modeId,
		players = players,
	})

	for _, modeKey in MatchModes.all() do
		broadcastQueueUpdate(modeKey)
	end

	return true
end

local function maybeStartFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end
	if fillEndsAt[modeId] then
		return
	end
	if getQueueSize(modeId) < mode.minPlayers then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	fillEndsAt[modeId] = os.clock() + mode.fillTimeout
	broadcastQueueUpdate(modeId)

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		fillEndsAt[modeId] = nil
		startMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	pruneQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if not MatchStateService.isArenaAvailable() then
		broadcastQueueUpdate(modeId)
		return
	end

	local size = getQueueSize(modeId)
	if size == 0 then
		cancelFillTimer(modeId)
		return
	end

	if mode.maxPlayers > 0 and size >= mode.maxPlayers then
		startMatch(modeId)
		return
	end

	if mode.fillTimeout <= 0 and size >= mode.minPlayers then
		startMatch(modeId)
		return
	end

	if size >= mode.minPlayers then
		maybeStartFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
end

local function evaluateAllQueues()
	for _, modeId in MatchModes.all() do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.joinQueue(player, requestedModeId)
	local modeId = resolveModeId(requestedModeId)
	if not modeId then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		removeFromQueue(player, true)
	end

	playerQueue[player] = modeId
	table.insert(queues[modeId], player)
	evaluateQueue(modeId)
	sendQueueUpdate(player)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	local modeId = playerQueue[player]
	removeFromQueue(player)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	evaluateAllQueues()
end

function MatchmakingService.init(options)
	options = options or {}
	getRecommendedModeId = options.getRecommendedModeId

	initQueues()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "auto"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaAvailable(function()
		MatchmakingService.onArenaFreed()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_POLL_INTERVAL)
			for _, modeId in MatchModes.all() do
				if getQueueSize(modeId) > 0 then
					evaluateQueue(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
