local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
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

	playerQueue[player] = nil
	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if fillTimers[modeId] then
		local config = getModeConfig(modeId)
		if config and #queue < config.minPlayers then
			fillTimers[modeId].cancelled = true
			fillTimers[modeId] = nil
		end
	end
end

local function buildQueuePayload(modeId, player)
	local queue = ensureQueue(modeId)
	local config = getModeConfig(modeId)
	local pending = GameMatchState.isBusy()

	return {
		modeId = modeId,
		modeLabel = config and config.label or modeId,
		queued = #queue,
		needed = config and config.minPlayers or 1,
		maxPlayers = config and config.maxPlayers or 1,
		pending = pending,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = ensureQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueueUpdate(modeId)
	end
end

local function popPlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	GameMatchState.setBusy(true)
	for _, player in playerList do
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			inQueue = false,
			matchStarting = true,
		})
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	if GameMatchState.isBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local queue = ensureQueue(modeId)
	if #queue < config.minPlayers then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local startNow = function()
		fillTimers[modeId] = nil
		if GameMatchState.isBusy() then
			broadcastQueueUpdate(modeId)
			return
		end

		local queueNow = ensureQueue(modeId)
		if #queueNow < config.minPlayers then
			return
		end

		local count = math.min(#queueNow, config.maxPlayers)
		local players = popPlayers(modeId, count)
		launchMatch(modeId, players)
		broadcastAllQueues()
	end

	if config.fillTimeout > 0 and #queue < config.maxPlayers then
		local token = { cancelled = false }
		fillTimers[modeId] = token
		broadcastQueueUpdate(modeId)

		task.delay(config.fillTimeout, function()
			if token.cancelled or fillTimers[modeId] ~= token then
				return
			end
			startNow()
		end)
	else
		startNow()
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	local config = getModeConfig(modeId)
	if not config then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true, "already_queued"
		end
		removeFromQueue(player)
	end

	local queue = ensureQueue(modeId)
	if #queue >= config.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)

	return true, "joined"
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	broadcastAllQueues()

	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
