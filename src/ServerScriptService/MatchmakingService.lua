local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local bindables
local onMatchReady

local playerQueue = {}
local queues = {}
local fillTokens = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
		fillTokens[modeId] = 0
	end
	return queues[modeId]
end

local function livingPlayers(list)
	local alive = {}
	for _, player in list do
		if player.Parent then
			table.insert(alive, player)
		end
	end
	return alive
end

local function buildQueuePayload(modeId)
	local mode = getModeConfig(modeId)
	local queue = livingPlayers(ensureQueue(modeId))
	local pending = MatchStateService.isBusy()
	return {
		modeId = modeId,
		label = mode and mode.label or modeId,
		count = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		pending = pending,
		fillTimeout = MatchmakingConfig.FILL_TIMEOUT,
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId)
	for _, player in ensureQueue(modeId) do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function sendPlayerQueueState(player)
	local modeId = playerQueue[player]
	if not modeId then
		remotes.QueueUpdate:FireClient(player, { modeId = nil, inQueue = false })
		return
	end
	remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId))
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local queue = ensureQueue(modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	fillTokens[modeId] += 1
	broadcastQueue(modeId)
	return modeId
end

local function popMatchPlayers(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return {}
	end

	local queue = livingPlayers(ensureQueue(modeId))
	if #queue < mode.minPlayers then
		return {}
	end

	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}
	for i = 1, count do
		local player = queue[1]
		table.remove(queue, 1)
		playerQueue[player] = nil
		table.insert(matchPlayers, player)
	end

	fillTokens[modeId] += 1
	broadcastQueue(modeId)
	return matchPlayers
end

local function tryLaunchMatch(modeId)
	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local queue = livingPlayers(ensureQueue(modeId))
	if #queue < mode.minPlayers then
		return
	end

	local matchPlayers = popMatchPlayers(modeId)
	if #matchPlayers < mode.minPlayers then
		return
	end

	if onMatchReady then
		onMatchReady({
			mode = modeId,
			players = matchPlayers,
		})
	end
	if bindables.MatchReady then
		bindables.MatchReady:Fire({
			mode = modeId,
			players = matchPlayers,
		})
	end
end

local function scheduleFill(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	fillTokens[modeId] += 1
	local token = fillTokens[modeId]

	task.delay(MatchmakingConfig.FILL_TIMEOUT, function()
		if token ~= fillTokens[modeId] then
			return
		end
		tryLaunchMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local queue = livingPlayers(ensureQueue(modeId))
	if #queue < mode.minPlayers then
		broadcastQueue(modeId)
		return
	end

	if #queue >= mode.maxPlayers then
		tryLaunchMatch(modeId)
		return
	end

	scheduleFill(modeId)
	broadcastQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	if modeId == "auto" then
		modeId = MatchmakingConfig.resolveAutoMode(#Players:GetPlayers())
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return false, "unknown_mode"
	end

	if playerQueue[player] == modeId then
		sendPlayerQueueState(player)
		return true
	end

	removeFromQueue(player)
	playerQueue[player] = modeId
	table.insert(ensureQueue(modeId), player)
	evaluateQueue(modeId)
	sendPlayerQueueState(player)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		remotes.QueueUpdate:FireClient(player, { modeId = nil, inQueue = false })
		return
	end
	removeFromQueue(player)
	remotes.QueueUpdate:FireClient(player, { modeId = nil, inQueue = false })
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setBusy(false)
	for modeId in MatchmakingConfig.MODES do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(remoteFolder, bindableFolder, matchReadyCallback)
	remotes = remoteFolder
	bindables = bindableFolder
	onMatchReady = matchReadyCallback

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	if bindables.MatchEnded then
		bindables.MatchEnded.Event:Connect(function()
			MatchmakingService.onArenaFreed()
		end)
	end

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
