local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local bindables
local onMatchStart
local queues = {}
local playerQueue = {}
local stagedMatch = nil
local fillTimers = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getQueueCount(modeId)
	return #ensureQueue(modeId)
end

local function buildQueuePayload(player, modeId, status)
	local config = getModeConfig(modeId)
	if not config then
		return { inQueue = false }
	end

	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		playersInQueue = getQueueCount(modeId),
		playersNeeded = config.maxPlayers,
		minPlayers = config.minPlayers,
		status = status or "waiting",
	}

	if status == "pending" then
		payload.message = "Arena belegt — Match startet gleich"
	end

	return payload
end

local function broadcastQueueUpdate(modeId, status)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
		end
	end
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
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

	local config = getModeConfig(modeId)
	if config and #queue < config.minPlayers then
		clearFillTimer(modeId)
	end

	if player.Parent then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueueUpdate(modeId)
end

local function popReadyBatch(modeId)
	local config = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	if #queue < config.minPlayers then
		return nil
	end

	local count = math.min(#queue, config.maxPlayers)
	local batch = {}
	for i = 1, count do
		table.insert(batch, queue[i])
	end

	for i = count, 1, -1 do
		local queuedPlayer = queue[i]
		table.remove(queue, i)
		playerQueue[queuedPlayer] = nil
	end

	clearFillTimer(modeId)
	return batch
end

local function canStartNow(modeId)
	local config = getModeConfig(modeId)
	local count = getQueueCount(modeId)

	if count < config.minPlayers then
		return false
	end

	if count >= config.maxPlayers then
		return true
	end

	if config.fillTimeout then
		return fillTimers[modeId] == nil
	end

	return count >= config.minPlayers
end

local function scheduleFillTimerIfNeeded(modeId)
	local config = getModeConfig(modeId)
	local count = getQueueCount(modeId)

	if not config.fillTimeout then
		return
	end

	if count >= config.minPlayers and count < config.maxPlayers and not fillTimers[modeId] then
		fillTimers[modeId] = task.delay(config.fillTimeout, function()
			fillTimers[modeId] = nil
			MatchmakingService.processQueues()
		end)
	end
end

local function launchMatch(players, modeId)
	MatchStateService.setArenaBusy(true)

	for _, player in players do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, {
				inQueue = false,
				status = "starting",
				modeId = modeId,
			})
		end
	end

	if onMatchStart then
		onMatchStart(players, modeId)
	end

	if bindables and bindables.MatchReady then
		bindables.MatchReady:Fire(players, modeId)
	end
end

local function tryStartMode(modeId)
	if not canStartNow(modeId) then
		scheduleFillTimerIfNeeded(modeId)
		return false
	end

	local batch = popReadyBatch(modeId)
	if not batch then
		return false
	end

	if MatchStateService.isArenaBusy() then
		stagedMatch = { players = batch, modeId = modeId }
		local config = getModeConfig(modeId)
		for _, player in batch do
			if player.Parent then
				remotes.QueueUpdate:FireClient(player, {
					inQueue = true,
					modeId = modeId,
					modeLabel = config.label,
					status = "pending",
					message = "Arena belegt — Match startet gleich",
				})
			end
		end
		return true
	end

	launchMatch(batch, modeId)
	return true
end

function MatchmakingService.processQueues()
	if stagedMatch and not MatchStateService.isArenaBusy() then
		local match = stagedMatch
		stagedMatch = nil
		launchMatch(match.players, match.modeId)
		return
	end

	if stagedMatch then
		return
	end

	for modeId in MatchmakingConfig.MODES do
		if tryStartMode(modeId) then
			return
		end
	end
end

function MatchmakingService.init(remoteFolder, bindableFolder, matchStartCallback)
	remotes = remoteFolder
	bindables = bindableFolder
	onMatchStart = matchStartCallback

	MatchStateService.onArenaFreed(function()
		MatchmakingService.processQueues()
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) or not player.Parent then
		return false
	end

	removeFromQueue(player)

	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, "waiting"))
	broadcastQueueUpdate(modeId)

	local config = getModeConfig(modeId)
	if config.maxPlayers and #queue >= config.maxPlayers then
		clearFillTimer(modeId)
	end

	MatchmakingService.processQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	return true
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)

	if not stagedMatch then
		return
	end

	for i, stagedPlayer in stagedMatch.players do
		if stagedPlayer == player then
			table.remove(stagedMatch.players, i)
			local config = getModeConfig(stagedMatch.modeId)
			if #stagedMatch.players < config.minPlayers then
				for _, remaining in stagedMatch.players do
					MatchmakingService.joinQueue(remaining, stagedMatch.modeId)
				end
				stagedMatch = nil
			end
			break
		end
	end
end

return MatchmakingService
