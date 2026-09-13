local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local Bindables
local callbacks = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local heartbeatConn

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidPlayer(player)
	return player and player.Parent and callbacks.getPhase and callbacks.getPhase(player) == "hub"
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local writeIdx = 1
	for readIdx = 1, #queue do
		local player = queue[readIdx]
		if isValidPlayer(player) then
			queue[writeIdx] = player
			writeIdx += 1
		else
			if playerQueue[player] == modeId then
				playerQueue[player] = nil
			end
		end
	end
	for idx = writeIdx, #queue do
		queue[idx] = nil
	end
end

local function cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		fillTimers[modeId] = nil
	end
	return timer
end

local function getQueueStatus(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return nil
	end

	pruneQueue(modeId)
	local count = #queues[modeId]
	local status = "waiting"
	if GameMatchState.isBusy() then
		status = "pending"
	elseif count >= config.minPlayers then
		status = fillTimers[modeId] and "filling" or "ready"
	end

	local fillTimeLeft
	local timer = fillTimers[modeId]
	if timer then
		fillTimeLeft = math.max(0, math.ceil(config.fillTimeout - (os.clock() - timer.startedAt)))
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		playersInQueue = count,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		fillTimeLeft = fillTimeLeft,
		arenaBusy = GameMatchState.isBusy(),
	}
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end

	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local payload = getQueueStatus(modeId)
	payload.inQueue = true
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function broadcastQueueUpdates(modeId)
	pruneQueue(modeId)
	for _, player in queues[modeId] do
		sendQueueUpdate(player)
	end
end

local function popPlayers(modeId, count)
	pruneQueue(modeId)
	local picked = {}
	local queue = queues[modeId]
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		playerQueue[player] = nil
		table.insert(picked, player)
	end
	return picked
end

local function launchMatch(modeId, players)
	cancelFillTimer(modeId)
	GameMatchState.setBusy(true)

	for _, player in players do
		if callbacks.leaveHubForArena then
			callbacks.leaveHubForArena(player)
		end
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	Bindables.MatchReady:Fire(players, modeId)
end

local function tryStartMatch(modeId)
	if GameMatchState.isBusy() then
		broadcastQueueUpdates(modeId)
		return
	end

	local config = getModeConfig(modeId)
	if not config then
		return
	end

	pruneQueue(modeId)
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	if #queue >= config.maxPlayers then
		launchMatch(modeId, popPlayers(modeId, config.maxPlayers))
		return
	end

	if config.fillTimeout > 0 then
		if not fillTimers[modeId] then
			local token = {}
			fillTimers[modeId] = {
				token = token,
				startedAt = os.clock(),
			}
			broadcastQueueUpdates(modeId)

			task.delay(config.fillTimeout, function()
				local timer = fillTimers[modeId]
				if not timer or timer.token ~= token then
					return
				end
				fillTimers[modeId] = nil

				if GameMatchState.isBusy() then
					broadcastQueueUpdates(modeId)
					return
				end

				pruneQueue(modeId)
				if #queues[modeId] < config.minPlayers then
					return
				end

				local count = math.min(#queues[modeId], config.maxPlayers)
				launchMatch(modeId, popPlayers(modeId, count))
			end)
		end
		return
	end

	launchMatch(modeId, popPlayers(modeId, config.maxPlayers))
end

local function tryStartAllQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false, "not_in_hub"
	end

	local config = getModeConfig(modeId)
	if not config then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for idx, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, idx)
			break
		end
	end

	pruneQueue(modeId)
	if #queues[modeId] < getModeConfig(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start(options)
	callbacks = options or {}
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		tryStartAllQueues()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if heartbeatConn then
		heartbeatConn:Disconnect()
	end

	local lastTick = 0
	heartbeatConn = game:GetService("RunService").Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTick < MatchmakingConfig.QUEUE_UPDATE_INTERVAL then
			return
		end
		lastTick = now

		for modeId in MatchmakingConfig.MODES do
			if #queues[modeId] > 0 then
				broadcastQueueUpdates(modeId)
			end
		end
	end)
end

return MatchmakingService
