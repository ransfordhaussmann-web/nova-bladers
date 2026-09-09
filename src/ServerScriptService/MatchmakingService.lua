local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local onMatchReady = nil
local onQueueChanged = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {
		players = {},
		fillToken = 0,
	}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

local function filterConnected(players)
	local connected = {}
	for _, player in players do
		if player.Parent then
			table.insert(connected, player)
		end
	end
	return connected
end

local function clearFillTimer(queue)
	queue.fillToken += 1
end

local function buildQueuePayload(modeId, player)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = #filterConnected(queue.players)
	local arenaBusy = MatchStateService.isArenaBusy()

	local status = "waiting"
	if arenaBusy then
		status = "pending"
	elseif modeId == "ffa" and count >= config.minPlayers and queue.fillDeadline then
		status = "filling"
	end

	local fillTimeLeft = nil
	if queue.fillDeadline then
		fillTimeLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		status = status,
		playersInQueue = count,
		playersNeeded = config.minPlayers,
		maxPlayers = config.maxPlayers,
		fillTimeLeft = fillTimeLeft,
		inQueue = playerQueue[player] == modeId,
	}
end

local function notifyPlayer(player)
	local modeId = playerQueue[player]
	if not modeId then
		if onQueueChanged then
			onQueueChanged(player, nil)
		end
		return
	end
	if onQueueChanged then
		onQueueChanged(player, buildQueuePayload(modeId, player))
	end
end

local function notifyMode(modeId)
	local queue = queues[modeId]
	for _, player in queue.players do
		notifyPlayer(player)
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerQueue[player] = nil

	local config = getModeConfig(modeId)
	if #filterConnected(queue.players) < config.minPlayers then
		clearFillTimer(queue)
		queue.fillDeadline = nil
	end

	notifyMode(modeId)
end

local function takePlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local connected = filterConnected(queue.players)
	local count = math.min(#connected, config.maxPlayers)

	local matchPlayers = {}
	for i = 1, count do
		matchPlayers[i] = connected[i]
	end

	for _, player in matchPlayers do
		playerQueue[player] = nil
	end

	queue.players = {}
	clearFillTimer(queue)
	queue.fillDeadline = nil

	return matchPlayers
end

local function startMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local connected = filterConnected(queue.players)
	if #connected < config.minPlayers then
		return
	end

	local matchPlayers = takePlayers(modeId)
	if #matchPlayers < config.minPlayers then
		return
	end

	MatchStateService.setArenaBusy(true)
	clearFillTimer(queue)

	for _, player in matchPlayers do
		if onQueueChanged then
			onQueueChanged(player, { status = "starting", modeId = modeId, inQueue = false })
		end
	end

	notifyMode(modeId)

	if onMatchReady then
		onMatchReady(matchPlayers, modeId)
	end
end

local function scheduleFfaFill(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	clearFillTimer(queue)

	local token = queue.fillToken
	queue.fillDeadline = os.clock() + config.fillTimeout

	task.delay(config.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		if MatchStateService.isArenaBusy() then
			return
		end
		local connected = filterConnected(queue.players)
		if #connected >= config.minPlayers then
			startMatch(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	if MatchStateService.isArenaBusy() then
		notifyMode(modeId)
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = #filterConnected(queue.players)

	if modeId == "training" and count >= 1 then
		startMatch(modeId)
		return
	end

	if modeId == "pvp" and count >= 2 then
		startMatch(modeId)
		return
	end

	if modeId == "ffa" then
		if count >= config.maxPlayers then
			startMatch(modeId)
			return
		end

		if count >= config.minPlayers and not queue.fillDeadline then
			scheduleFfaFill(modeId)
		end
	end

	notifyMode(modeId)
end

function MatchmakingService.setCallbacks(callbacks)
	onMatchReady = callbacks.onMatchReady
	onQueueChanged = callbacks.onQueueChanged
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if playerQueue[player] == modeId then
		notifyPlayer(player)
		return true
	end

	removePlayerFromQueue(player)
	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removePlayerFromQueue(player)
	if onQueueChanged then
		onQueueChanged(player, nil)
	end
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	for modeId in MatchmakingConfig.MODES do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removePlayerFromQueue(player)
end

function MatchmakingService.tickQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			notifyPlayer(player)
		end
	end
end

return MatchmakingService
