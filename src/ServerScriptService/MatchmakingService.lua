local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local fillTimers = {}
local initialized = false

local Remotes
local MatchReady
local MatchEnded

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil

	if #queue == 0 then
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local entry = playerEntry[player]
	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif position > 0 and #queue >= config.minPlayers then
		status = "ready"
	end

	local fillStartedAt = fillTimers[modeId]
	local fillRemaining = nil
	if fillStartedAt and config.fillTimeout > 0 then
		fillRemaining = math.max(0, config.fillTimeout - (os.clock() - fillStartedAt))
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		status = status,
		position = position,
		queueSize = #queue,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		fillRemaining = fillRemaining,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	if not Remotes then
		return
	end

	local queue = queues[modeId]
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function setPlayersArenaPhase(players)
	for _, player in players do
		HubService.enterArenaPhase(player)
	end
end

local function startMatch(modeId, players)
	local config = getModeConfig(modeId)
	for _, player in players do
		removeFromQueue(player)
	end

	MatchStateService.setArenaBusy(true)
	setPlayersArenaPhase(players)

	if MatchReady then
		MatchReady:Fire(modeId, players)
	end
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	local playerCount = math.min(#queue, config.maxPlayers)
	if modeId == "ffa" and #queue < config.maxPlayers then
		local fillStartedAt = fillTimers[modeId]
		if not fillStartedAt then
			return
		end
		if os.clock() - fillStartedAt < config.fillTimeout then
			return
		end
	end

	local matchPlayers = {}
	for i = 1, playerCount do
		table.insert(matchPlayers, queue[i])
	end

	startMatch(modeId, matchPlayers)
end

local function ensureFillTimer(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if config.fillTimeout <= 0 or #queue < config.minPlayers then
		fillTimers[modeId] = nil
		return
	end

	if not fillTimers[modeId] then
		fillTimers[modeId] = os.clock()
	end
end

function MatchmakingService.init()
	ensureInitialized()
end

function MatchmakingService.resolveModeId(requestedModeId)
	if requestedModeId and MatchmakingConfig.MODES[requestedModeId] then
		return requestedModeId
	end

	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function ensureInitialized()
	if initialized then
		return
	end
	initialized = true

	local bindables
	Remotes, bindables = RemotesSetup.ensure()
	MatchReady = bindables.MatchReady
	MatchEnded = bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId ~= nil and typeof(modeId) ~= "string" then
			return
		end
		local resolved = MatchmakingService.resolveModeId(modeId)
		local ok, reason = MatchmakingService.joinQueue(player, resolved)
		if not ok then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = resolved,
				status = "error",
				reason = reason,
			})
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		Remotes.QueueUpdate:FireClient(player, { status = "left" })
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			MatchmakingService.tick()
		end
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	ensureInitialized()
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerEntry[player] then
		return false, "already_queued"
	end
	if HubService.getPhase(player) == "arena" then
		return false, "in_match"
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	ensureFillTimer(modeId)
	broadcastQueueUpdate(modeId)

	if modeId == "training" or (modeId == "pvp" and #queues[modeId] >= 2) then
		tryStartMatch(modeId)
	elseif not MatchStateService.isArenaBusy() then
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return false
	end

	local modeId = entry.modeId
	removeFromQueue(player)
	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.getPlayerQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end
	return buildQueuePayload(entry.modeId, player)
end

function MatchmakingService.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(function()
		for modeId in queues do
			ensureFillTimer(modeId)
			tryStartMatch(modeId)
		end
		broadcastAllQueues()
	end)
end

function MatchmakingService.onPlayerRemoving(player)
	if playerEntry[player] then
		local modeId = playerEntry[player].modeId
		removeFromQueue(player)
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.tick()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

MatchStateService.onArenaFreed(function()
	for modeId in queues do
		ensureFillTimer(modeId)
		tryStartMatch(modeId)
	end
	broadcastAllQueues()
end)

return MatchmakingService
