local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaTimerToken = 0

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueueList(player, modeId)
	local queue = queues[modeId]
	for i, queuedPlayer in ipairs(queue) do
		if queuedPlayer == player then
			table.remove(queue, i)
			return
		end
	end
end

local function buildQueueStatus(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in ipairs(queue) do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		position = position,
		total = #queue,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
	}
end

local function sendQueueStatus(player)
	if player.Parent then
		Remotes.QueueStatus:FireClient(player, buildQueueStatus(player))
	end
end

local function broadcastAllQueueStatus()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			sendQueueStatus(player)
		end
	end
end

local function pullPlayers(modeId, count)
	local pulled = {}
	for _ = 1, count do
		local player = queues[modeId][1]
		if not player then
			break
		end
		table.remove(queues[modeId], 1)
		playerQueue[player] = nil
		table.insert(pulled, player)
	end
	return pulled
end

local function launchMatch(players, modeId)
	for _, player in players do
		HubService.prepareForMatch(player)
		sendQueueStatus(player)
	end
	Bindables.StartMatch:Fire(players, modeId)
	broadcastAllQueueStatus()
end

local function tryStartMatch(modeId)
	if not MatchmakingService.canStartMatch() then
		return
	end

	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	local count = math.min(#queue, config.maxPlayers)
	local players = pullPlayers(modeId, count)
	if #players >= config.minPlayers then
		launchMatch(players, modeId)
	end
end

local function tryStartFfaOnTimeout()
	if not MatchmakingService.canStartMatch() then
		return
	end

	local config = getModeConfig("ffa")
	local queue = queues.ffa
	if #queue < config.minPlayersOnTimeout or #queue >= config.minPlayers then
		return
	end

	local count = math.min(#queue, config.maxPlayers)
	local players = pullPlayers("ffa", count)
	if #players >= config.minPlayersOnTimeout then
		launchMatch(players, "ffa")
	end
end

local function scheduleFfaTimeout()
	ffaTimerToken += 1
	local token = ffaTimerToken
	local timeout = getModeConfig("ffa").fillTimeout

	task.delay(timeout, function()
		if token ~= ffaTimerToken then
			return
		end
		tryStartFfaOnTimeout()
	end)
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueueList(player, modeId)
	playerQueue[player] = nil

	if modeId == "ffa" and #queues.ffa == 0 then
		ffaTimerToken += 1
	end

	sendQueueStatus(player)
	broadcastAllQueueStatus()
end

local function joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		leaveQueue(player)
	end

	if not MatchmakingService.canStartMatch() and playerQueue[player] == nil then
		-- Allow joining queue while match runs; players wait until idle
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueStatus(player)
	broadcastAllQueueStatus()

	if modeId == "ffa" then
		if #queues.ffa == 1 then
			scheduleFfaTimeout()
		elseif #queues.ffa >= getModeConfig("ffa").minPlayers then
			ffaTimerToken += 1
		end
	end

	tryStartMatch(modeId)
	return true
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, payload)
	local modeId = payload and payload.modeId
	if typeof(modeId) ~= "string" then
		return
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	-- Legacy fallback: join auto-detected mode queue
	local count = #Players:GetPlayers()
	local modeId = "training"
	if count >= 3 then
		modeId = "ffa"
	elseif count == 2 then
		modeId = "pvp"
	end
	joinQueue(player, modeId)
end)

Players.PlayerRemoving:Connect(function(player)
	leaveQueue(player)
end)

local function retryAllQueues()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

MatchmakingService.register({
	joinQueue = joinQueue,
	leaveQueue = leaveQueue,
	getQueueMode = function(player)
		return playerQueue[player]
	end,
	onMatchEnded = retryAllQueues,
})

-- Periodic queue status refresh for waiting players
task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.STATUS_BROADCAST_INTERVAL)
		broadcastAllQueueStatus()
	end
end)

print("[MatchmakingManager] Queue system ready")
