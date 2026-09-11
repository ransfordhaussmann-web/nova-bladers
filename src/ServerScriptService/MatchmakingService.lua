local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTimers = {}
local remotes
local matchReadyEvent
local onLeaveHub

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function buildQueueSnapshot(modeId)
	local queue = queues[modeId] or {}
	local mode = getModeConfig(modeId)
	local snapshot = {
		modeId = modeId,
		label = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		pending = arenaBusy,
	}

	if fillTimers[modeId] then
		snapshot.fillSecondsRemaining = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
	end

	return snapshot
end

local function sendQueueUpdate(player)
	if not remotes then
		return
	end

	local entry = playerQueue[player]
	if not entry then
		remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
		})
		return
	end

	remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		modeId = entry.modeId,
		queue = buildQueueSnapshot(entry.modeId),
	})
end

local function broadcastQueue(modeId)
	if not remotes then
		return
	end

	local queue = queues[modeId] or {}
	local snapshot = buildQueueSnapshot(modeId)
	for _, player in queue do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				modeId = modeId,
				queue = snapshot,
			})
		end
	end
end

local function cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		if timer.thread then
			task.cancel(timer.thread)
		end
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	playerQueue[player] = nil

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
		if #queue == 0 then
			cancelFillTimer(modeId)
		end
		broadcastQueue(modeId)
	end

	sendQueueUpdate(player)
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	if not queue then
		return {}
	end

	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end

	cancelFillTimer(modeId)
	broadcastQueue(modeId)
	return taken
end

local function startMatch(modeId, playerList)
	arenaBusy = true
	for _, player in playerList do
		sendQueueUpdate(player)
		if onLeaveHub then
			onLeaveHub(player)
		end
	end
	matchReadyEvent:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMode(modeId)
	if arenaBusy then
		broadcastQueue(modeId)
		return
	end

	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	if not queue or #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			startMatch(modeId, takePlayers(modeId, mode.maxPlayers))
			return
		end

		if not fillTimers[modeId] then
			local endsAt = os.clock() + mode.fillTimeout
			fillTimers[modeId] = { endsAt = endsAt }
			broadcastQueue(modeId)

			local thread = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				if arenaBusy then
					broadcastQueue(modeId)
					return
				end
				local currentQueue = queues[modeId]
				if currentQueue and #currentQueue >= mode.minPlayers then
					startMatch(modeId, takePlayers(modeId, #currentQueue))
				end
			end)
			fillTimers[modeId].thread = thread
		end
		return
	end

	startMatch(modeId, takePlayers(modeId, mode.maxPlayers))
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

function MatchmakingService.init(remoteFolder, bindables, options)
	remotes = remoteFolder
	matchReadyEvent = bindables.MatchReady
	onLeaveHub = options.leaveHubForArena

	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
		if not busy then
			tryStartMode(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return false, "unknown_mode"
	end

	if arenaBusy and not playerQueue[player] then
		-- Allow re-queue updates while pending, but new joins get pending state.
	end

	removeFromQueue(player)

	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }

	broadcastQueue(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.handlePlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.handlePlayerRemoving(player)
end)

return MatchmakingService
