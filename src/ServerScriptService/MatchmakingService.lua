local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local arenaBusy = false

local remotes = nil
local bindables = nil
local initialized = false

local function ensureInit()
	if initialized then
		return
	end

	local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
	remotes, bindables = RemotesSetup.ensure()
	MatchmakingService.init(remotes, bindables)
	initialized = true
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function buildQueueSnapshot(modeId)
	local queue = queues[modeId]
	local config = getModeConfig(modeId)
	if not queue or not config then
		return nil
	end

	local names = {}
	for _, queuedPlayer in queue.players do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	return {
		modeId = modeId,
		label = config.label,
		players = names,
		count = #names,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		fillTimeout = config.fillTimeout,
		fillSecondsLeft = queue.fillSecondsLeft,
		status = queue.status,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local snapshot = buildQueueSnapshot(modeId)
	if snapshot then
		remotes.QueueUpdate:FireClient(player, {
			inQueue = true,
			queue = snapshot,
		})
	end
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for _, queuedPlayer in queue.players do
		if queuedPlayer.Parent then
			sendQueueUpdate(queuedPlayer)
		end
	end
end

local function setQueueStatus(modeId, status)
	local queue = queues[modeId]
	if queue then
		queue.status = status
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end

	local queue = queues[modeId]
	if queue then
		queue.fillSecondsLeft = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	playerQueue[player] = nil

	if queue then
		for i, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, i)
				break
			end
		end

		if #queue.players < getModeConfig(modeId).minPlayers then
			clearFillTimer(modeId)
			if queue.status ~= "waiting" then
				queue.status = "waiting"
			end
		end

		broadcastQueue(modeId)
	end

	sendQueueUpdate(player)
end

local function pullPlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local pulled = {}

	for i = 1, math.min(#queue.players, config.maxPlayers) do
		table.insert(pulled, queue.players[i])
	end

	for _, player in pulled do
		playerQueue[player] = nil
	end

	queue.players = {}
	clearFillTimer(modeId)
	queue.status = "waiting"
	broadcastQueue(modeId)

	return pulled
end

local function launchMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not queue or #queue.players < config.minPlayers then
		return
	end

	if arenaBusy then
		setQueueStatus(modeId, "pending")
		return
	end

	local players = pullPlayers(modeId)
	if #players < config.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	arenaBusy = true
	setQueueStatus(modeId, "starting")
	bindables.MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

local function tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not queue or #queue.players < config.minPlayers then
		return
	end

	if config.maxPlayers and #queue.players >= config.maxPlayers then
		clearFillTimer(modeId)
		launchMatch(modeId)
		return
	end

	if not config.fillTimeout then
		launchMatch(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	queue.fillSecondsLeft = config.fillTimeout
	setQueueStatus(modeId, "filling")

	fillTimers[modeId] = task.spawn(function()
		while queue.fillSecondsLeft and queue.fillSecondsLeft > 0 do
			task.wait(1)
			if not queues[modeId] or #queue.players < config.minPlayers then
				clearFillTimer(modeId)
				setQueueStatus(modeId, "waiting")
				return
			end
			queue.fillSecondsLeft -= 1
			broadcastQueue(modeId)
		end

		clearFillTimer(modeId)
		if #queue.players >= config.minPlayers then
			launchMatch(modeId)
		else
			setQueueStatus(modeId, "waiting")
		end
	end)
end

function MatchmakingService.init(remotesFolder, bindablesFolder)
	if initialized then
		return
	end

	remotes = remotesFolder
	bindables = bindablesFolder

	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {
			players = {},
			status = "waiting",
			fillSecondsLeft = nil,
		}
	end

	bindables.MatchEnded.Event:Connect(function()
		arenaBusy = false
		for modeId in MatchmakingConfig.MODES do
			tryStartMatch(modeId)
		end
	end)

	initialized = true
end

function MatchmakingService.joinQueue(player, modeId)
	ensureInit()
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return false, "invalid_mode"
	end

	removeFromQueue(player)

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerQueue[player] = modeId
	queue.status = arenaBusy and #queue.players >= getModeConfig(modeId).minPlayers and "pending" or "waiting"

	sendQueueUpdate(player)
	broadcastQueue(modeId)
	tryStartMatch(modeId)

	return true
end

function MatchmakingService.leaveQueue(player)
	ensureInit()
	if not playerQueue[player] then
		return false
	end

	removeFromQueue(player)
	return true
end

function MatchmakingService.onPlayerRemoving(player)
	if not initialized then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.isPlayerQueued(player)
	ensureInit()
	return playerQueue[player] ~= nil
end

return MatchmakingService
