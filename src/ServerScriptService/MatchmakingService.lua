local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local arenaBusy = false
local ffaFillToken = 0
local remotes = nil
local bindables = nil
local onMatchStarting = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countQueue(modeId)
	return #queues[modeId]
end

local function isPlayerInQueue(player)
	return playerMode[player] ~= nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end
	playerMode[player] = nil

	if modeId == "ffa" and countQueue("ffa") < MatchmakingConfig.MODES.ffa.minPlayers then
		ffaFillToken += 1
	end
end

local function buildStatusText(modeId, queueCount, status)
	local mode = getModeConfig(modeId)
	if not mode then
		return ""
	end

	if status == "pending" then
		return "Arena belegt — Match startet gleich..."
	end
	if status == "starting" then
		return "Match startet..."
	end
	if modeId == "ffa" then
		return string.format("FFA: %d/%d Spieler (min. %d)", queueCount, mode.maxPlayers, mode.minPlayers)
	end
	return string.format("%s: %d/%d Spieler", mode.label, queueCount, mode.maxPlayers)
end

local function broadcastQueueUpdate(player, status)
	if not remotes or not player.Parent then
		return
	end

	local modeId = playerMode[player]
	if not modeId then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local mode = getModeConfig(modeId)
	remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queueCount = countQueue(modeId),
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		statusText = buildStatusText(modeId, countQueue(modeId), status),
		arenaBusy = arenaBusy,
	})
end

local function broadcastModeQueue(modeId, status)
	for _, player in queues[modeId] do
		if player.Parent then
			broadcastQueueUpdate(player, status)
		end
	end
end

local function collectReadyPlayers(modeId)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = #queue

	if count < mode.minPlayers then
		return nil
	end

	local take = math.min(count, mode.maxPlayers)
	local ready = {}
	for i = 1, take do
		table.insert(ready, queue[i])
	end
	return ready
end

local function startMatch(modeId, players)
	arenaBusy = true
	ffaFillToken += 1

	for _, player in players do
		removeFromQueue(player)
	end

	broadcastModeQueue(modeId, "starting")

	if onMatchStarting then
		onMatchStarting(players)
	end

	if bindables and bindables.MatchReady then
		bindables.MatchReady:Fire(modeId, players)
	end
end

local function tryStartMode(modeId)
	if arenaBusy then
		local mode = getModeConfig(modeId)
		if countQueue(modeId) >= mode.minPlayers then
			broadcastModeQueue(modeId, "pending")
		end
		return
	end

	local players = collectReadyPlayers(modeId)
	if players then
		startMatch(modeId, players)
	end
end

local function tryStartAllQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

local function scheduleFfaFill()
	local mode = MatchmakingConfig.MODES.ffa
	if countQueue("ffa") < mode.minPlayers then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	local timeout = mode.fillTimeout or 12

	task.delay(timeout, function()
		if token ~= ffaFillToken then
			return
		end
		tryStartMode("ffa")
	end)
end

function MatchmakingService.init(opts)
	remotes = opts.remotes
	bindables = opts.bindables
	onMatchStarting = opts.onMatchStarting

	if bindables and bindables.MatchEnded then
		bindables.MatchEnded.Event:Connect(function()
			arenaBusy = false
			task.defer(tryStartAllQueues)
		end)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return false, "invalid_mode"
	end

	if isPlayerInQueue(player) then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	broadcastQueueUpdate(player, arenaBusy and countQueue(modeId) >= getModeConfig(modeId).minPlayers and "pending" or "waiting")
	broadcastModeQueue(modeId)

	if modeId == "ffa" and countQueue("ffa") >= MatchmakingConfig.MODES.ffa.minPlayers then
		scheduleFfaFill()
	end

	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not isPlayerInQueue(player) then
		return
	end

	local modeId = playerMode[player]
	removeFromQueue(player)

	if remotes and player.Parent then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	if modeId then
		broadcastModeQueue(modeId)
	end
end

function MatchmakingService.getQueueState(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local mode = getModeConfig(modeId)
	local count = countQueue(modeId)
	local status = "waiting"
	if arenaBusy and count >= mode.minPlayers then
		status = "pending"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queueCount = count,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		statusText = buildStatusText(modeId, count, status),
		arenaBusy = arenaBusy,
	}
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

return MatchmakingService
