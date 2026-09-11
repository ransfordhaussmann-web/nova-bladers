local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)

local MatchmakingService = {}

local initialized = false
local remotes
local bindables
local onMatchStart

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local arenaBusy = false
local ffaTimerToken = 0
local ffaTimerEndsAt = 0

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
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

	playerQueue[player] = nil

	if modeId == "ffa" and #queue == 0 then
		ffaTimerToken += 1
		ffaTimerEndsAt = 0
	end
end

local function getQueueStatus(player)
	if not playerQueue[player] then
		return MatchState.QueueStatus.Idle
	end
	if arenaBusy then
		return MatchState.QueueStatus.Pending
	end
	return MatchState.QueueStatus.Searching
end

local function buildUpdatePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { status = MatchState.QueueStatus.Idle }
	end

	local config = getModeConfig(modeId)
	local count = queueCount(modeId)
	local remaining = 0
	if modeId == "ffa" and ffaTimerEndsAt > 0 then
		remaining = math.max(0, math.ceil(ffaTimerEndsAt - os.clock()))
	end

	return {
		status = getQueueStatus(player),
		mode = modeId,
		modeLabel = config.label,
		playersInQueue = count,
		playersNeeded = config.minPlayers,
		maxPlayers = config.maxPlayers,
		fillTimeoutRemaining = remaining,
	}
end

local function sendQueueUpdate(player)
	if remotes and remotes.QueueUpdate then
		remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
	end
end

local function broadcastQueueUpdates()
	for modeId, queue in queues do
		for _, player in queue do
			sendQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function canStartMode(modeId)
	local config = getModeConfig(modeId)
	local count = queueCount(modeId)
	if count < config.minPlayers then
		return false
	end

	if modeId == "ffa" then
		if count >= config.maxPlayers then
			return true
		end
		if ffaTimerEndsAt > 0 and os.clock() >= ffaTimerEndsAt then
			return true
		end
		return false
	end

	return count >= config.minPlayers
end

local function startMatch(modeId)
	if arenaBusy then
		broadcastQueueUpdates()
		return
	end

	local config = getModeConfig(modeId)
	if not canStartMode(modeId) then
		return
	end

	local takeCount = math.min(queueCount(modeId), config.maxPlayers)
	local players = popPlayers(modeId, takeCount)
	if #players == 0 then
		return
	end

	if modeId == "ffa" then
		ffaTimerToken += 1
		ffaTimerEndsAt = 0
	end

	arenaBusy = true
	broadcastQueueUpdates()

	if onMatchStart then
		onMatchStart(modeId, players)
	end

	if bindables and bindables.MatchReady then
		bindables.MatchReady:Fire({
			mode = modeId,
			players = players,
		})
	end
end

local function tryStartAllQueues()
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		if canStartMode(modeId) then
			startMatch(modeId)
			return
		end
	end
	broadcastQueueUpdates()
end

local function startFfaTimer()
	if queueCount("ffa") == 0 or ffaTimerEndsAt > 0 then
		return
	end

	ffaTimerToken += 1
	local token = ffaTimerToken
	local config = getModeConfig("ffa")
	ffaTimerEndsAt = os.clock() + config.fillTimeout

	task.delay(config.fillTimeout, function()
		if token ~= ffaTimerToken then
			return
		end
		tryStartAllQueues()
	end)

	broadcastQueueUpdates()
end

function MatchmakingService.init(remoteFolder, bindableFolder, matchStartCallback)
	if initialized then
		return
	end
	initialized = true

	remotes = remoteFolder
	bindables = bindableFolder
	onMatchStart = matchStartCallback

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if bindables.MatchEnded then
		bindables.MatchEnded.Event:Connect(function()
			MatchmakingService.onMatchEnded()
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if modeId == "ffa" and queueCount("ffa") == 1 then
		startFfaTimer()
	end

	sendQueueUpdate(player)
	tryStartAllQueues()
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	removeFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdates()
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	tryStartAllQueues()
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

return MatchmakingService
