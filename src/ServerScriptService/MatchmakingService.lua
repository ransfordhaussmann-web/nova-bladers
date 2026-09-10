local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTokens = {}
local callbacks = {}

for _, modeId in MatchmakingConfig.MODE_ORDER do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function playerName(player)
	return player.DisplayName or player.Name
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local list = queues[modeId]
	local names = {}
	for _, player in list do
		if player.Parent then
			table.insert(names, playerName(player))
		end
	end
	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = #list,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		players = names,
		arenaBusy = arenaBusy,
		status = arenaBusy and "pending" or "waiting",
	}
end

local function notifyPlayer(player, payload)
	if callbacks.onQueueUpdate and player.Parent then
		callbacks.onQueueUpdate(player, payload)
	end
end

local function notifyQueue(modeId)
	local payload = buildQueuePayload(modeId)
	for _, player in queues[modeId] do
		notifyPlayer(player, payload)
	end
end

local function notifyLeft(player)
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { inQueue = false })
	end
end

local function pruneQueue(modeId)
	local list = queues[modeId]
	local alive = {}
	for _, player in list do
		if player.Parent and playerQueue[player] == modeId then
			table.insert(alive, player)
		end
	end
	queues[modeId] = alive
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode.fillTimeout then
		return
	end

	cancelFillTimer(modeId)
	local token = fillTokens[modeId] or 0
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.registerHandlers(handlers)
	callbacks = handlers or {}
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		MatchmakingService.processReadyQueues()
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		notifyLeft(player)
		return
	end

	playerQueue[player] = nil
	pruneQueue(modeId)
	cancelFillTimer(modeId)
	notifyLeft(player)
	notifyQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		local payload = buildQueuePayload(modeId)
		payload.inQueue = true
		notifyPlayer(player, payload)
		return true
	end

	MatchmakingService.leaveQueue(player)

	local list = queues[modeId]
	if #list >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(list, player)
	playerQueue[player] = modeId

	local payload = buildQueuePayload(modeId)
	payload.inQueue = true
	notifyPlayer(player, payload)
	notifyQueue(modeId)

	if modeId == "ffa" and #list >= mode.minPlayers then
		startFillTimer(modeId)
	end

	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.tryStartMatch(modeId)
	if arenaBusy then
		local mode = getMode(modeId)
		if #queues[modeId] >= mode.minPlayers then
			notifyQueue(modeId)
		end
		return
	end

	pruneQueue(modeId)
	local mode = getMode(modeId)
	local list = queues[modeId]
	if #list < mode.minPlayers then
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(#list, mode.maxPlayers) do
		table.insert(matchPlayers, list[i])
	end

	for _, player in matchPlayers do
		playerQueue[player] = nil
	end
	queues[modeId] = {}
	cancelFillTimer(modeId)

	arenaBusy = true
	for _, player in matchPlayers do
		notifyLeft(player)
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, matchPlayers)
	end
end

function MatchmakingService.processReadyQueues()
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		pruneQueue(modeId)
		local mode = getMode(modeId)
		if #queues[modeId] >= mode.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
			if arenaBusy then
				return
			end
		end
	end
end

function MatchmakingService.resolveAutoMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

return MatchmakingService
