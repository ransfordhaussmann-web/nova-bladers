local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTokens = {}
local fillTimers = {}
local padDebounce = {}
local remotes
local bindables
local callbacks

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
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local queue = ensureQueue(modeId)
	for index, queuedPlayer in ipairs(queue) do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
	fillTokens[modeId] = nil

	return modeId
end

local function getQueueStatus(modeId, player)
	local mode = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local position = 0

	for index, queuedPlayer in ipairs(queue) do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local status = "waiting"
	if GameMatchState.isBusy() then
		status = "pending"
	elseif #queue >= mode.minPlayers and position > 0 and position <= mode.maxPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = status,
		arenaBusy = GameMatchState.isBusy(),
	}
end

local function broadcastQueue(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, getQueueStatus(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
	end
end

local function popPlayers(modeId)
	local mode = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local matchPlayers = {}

	while #matchPlayers < mode.maxPlayers and #queue > 0 do
		local player = table.remove(queue, 1)
		if player.Parent then
			table.insert(matchPlayers, player)
			playerMode[player] = nil
		end
	end

	return matchPlayers
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = nil
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId, mode)
	cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		if token ~= fillTokens[modeId] then
			return
		end
		tryStartMode(modeId)
	end)
end

local function tryStartMode(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	if GameMatchState.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		cancelFillTimer(modeId)
		return
	end

	if mode.fillTimeout > 0 and #queue < mode.maxPlayers then
		if not fillTimers[modeId] then
			startFillTimer(modeId, mode)
		end
		broadcastQueue(modeId)
		return
	end

	cancelFillTimer(modeId)

	local matchPlayers = popPlayers(modeId)
	if #matchPlayers < mode.minPlayers then
		for _, player in matchPlayers do
			table.insert(queue, player)
			playerMode[player] = modeId
		end
		return
	end

	cancelFillTimer(modeId)

	GameMatchState.setBusy(true)
	bindables.MatchReady:Fire(matchPlayers, modeId)
	broadcastAllQueues()
end

local function tryStartAllModes()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
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

	if callbacks.getPhase(player) == "arena" then
		return false, "in_match"
	end

	if playerMode[player] == modeId then
		return true, "already_queued"
	end

	removeFromQueue(player)

	local queue = ensureQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerMode[player] = modeId

	if callbacks.onJoinQueue then
		callbacks.onJoinQueue(player, modeId)
	end

	remotes.QueueUpdate:FireClient(player, getQueueStatus(modeId, player))
	broadcastQueue(modeId)
	tryStartMode(modeId)

	return true, "joined"
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return false
	end

	if callbacks.onLeaveQueue then
		callbacks.onLeaveQueue(player)
	end

	broadcastQueue(modeId)
	return true
end

function MatchmakingService.getQuickMatchMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	broadcastAllQueues()
	tryStartAllModes()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.canTouchPad(player)
	local lastTouch = padDebounce[player]
	if lastTouch and os.clock() - lastTouch < MatchmakingConfig.PAD_DEBOUNCE then
		return false
	end
	padDebounce[player] = os.clock()
	return true
end

function MatchmakingService.start(options)
	remotes = options.remotes
	bindables = options.bindables
	callbacks = options.callbacks or {}

	for modeId in MatchmakingConfig.MODES do
		ensureQueue(modeId)
	end

	remotes.QueueJoin.OnServerEvent:Connect(function(player, payload)
		local modeId = payload
		if typeof(payload) == "table" then
			modeId = payload.modeId
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		padDebounce[player] = nil
		MatchmakingService.onPlayerRemoving(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
