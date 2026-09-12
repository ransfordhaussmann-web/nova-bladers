local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)

local MatchmakingService = {}

local queues = {}
local playerToMode = {}
local fillTasks = {}
local Remotes
local MatchReady
local leaveHubForArena

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

local function cancelFillTimer(modeId)
	fillTasks[modeId] = nil
end

local function getQueueStatus(modeId)
	local mode = getModeConfig(modeId)
	local count = #queues[modeId]

	if GameMatchState.isBusy() then
		return MatchState.QueueStatus.Pending
	end
	if count >= mode.maxPlayers then
		return MatchState.QueueStatus.Ready
	end
	if modeId == "training" and count >= 1 then
		return MatchState.QueueStatus.Ready
	end
	if modeId == "pvp" and count >= 2 then
		return MatchState.QueueStatus.Ready
	end
	if modeId == "ffa" and count >= mode.minPlayers then
		return MatchState.QueueStatus.Ready
	end
	if count > 0 then
		return MatchState.QueueStatus.Waiting
	end
	return MatchState.QueueStatus.Idle
end

local function buildPayload(player, modeId)
	local mode = getModeConfig(modeId)
	local fillTask = fillTasks[modeId]
	return {
		inQueue = playerToMode[player] == modeId,
		modeId = modeId,
		modeLabel = mode.label,
		queueCount = #queues[modeId],
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = getQueueStatus(modeId),
		fillSeconds = fillTask and fillTask.remaining or nil,
	}
end

local function broadcastQueueUpdates()
	for modeId, members in queues do
		for _, player in members do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, buildPayload(player, modeId))
			end
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerToMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerToMode[player] = nil
	cancelFillTimer(modeId)
end

local function tryStartMatch(modeId)
	if GameMatchState.isBusy() then
		return false
	end

	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return false
	end
	if modeId == "pvp" and #queue < 2 then
		return false
	end

	local playerList = {}
	local takeCount = math.min(#queue, mode.maxPlayers)
	for _ = 1, takeCount do
		local nextPlayer = table.remove(queue, 1)
		playerToMode[nextPlayer] = nil
		table.insert(playerList, nextPlayer)
	end

	cancelFillTimer(modeId)

	for _, player in playerList do
		if leaveHubForArena then
			leaveHubForArena(player)
		end
	end

	MatchReady:Fire(playerList, modeId)
	broadcastQueueUpdates()
	return true
end

local function startFillTimer(modeId)
	local mode = getModeConfig(modeId)
	if not mode.fillTimeout then
		return
	end

	cancelFillTimer(modeId)
	local token = {}
	fillTasks[modeId] = {
		token = token,
		remaining = mode.fillTimeout,
	}

	task.spawn(function()
		local remaining = mode.fillTimeout
		while remaining > 0 do
			task.wait(1)
			remaining -= 1

			local activeTask = fillTasks[modeId]
			if not activeTask or activeTask.token ~= token then
				return
			end
			if #queues[modeId] < mode.minPlayers then
				cancelFillTimer(modeId)
				broadcastQueueUpdates()
				return
			end

			activeTask.remaining = remaining
			broadcastQueueUpdates()
		end

		local activeTask = fillTasks[modeId]
		if activeTask and activeTask.token == token and not GameMatchState.isBusy() then
			tryStartMatch(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	if GameMatchState.isBusy() then
		broadcastQueueUpdates()
		return
	end

	local mode = getModeConfig(modeId)
	local count = #queues[modeId]

	if modeId == "training" and count >= 1 then
		tryStartMatch(modeId)
	elseif modeId == "pvp" and count >= 2 then
		tryStartMatch(modeId)
	elseif modeId == "ffa" and count >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif modeId == "ffa" and count >= mode.minPlayers then
		if not fillTasks[modeId] then
			startFillTimer(modeId)
		end
	end

	broadcastQueueUpdates()
end

local function processIdleQueues()
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		local mode = getModeConfig(modeId)
		local count = #queues[modeId]
		if count >= mode.minPlayers and (modeId ~= "pvp" or count >= 2) then
			if tryStartMatch(modeId) then
				return
			end
			if modeId == "ffa" and count >= mode.minPlayers and not fillTasks[modeId] then
				startFillTimer(modeId)
				return
			end
		end
	end
	broadcastQueueUpdates()
end

local function leaveQueue(player)
	if not playerToMode[player] then
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			status = MatchState.QueueStatus.Idle,
		})
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = false,
		status = MatchState.QueueStatus.Idle,
	})
	broadcastQueueUpdates()
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if playerToMode[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerToMode[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildPayload(player, modeId))
	evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.start(deps)
	Remotes = deps.remotes
	MatchReady = deps.matchReady
	leaveHubForArena = deps.leaveHubForArena

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingConfig.DEFAULT_MODE
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		broadcastQueueUpdates()
	end)

	GameMatchState.onIdle(processIdleQueues)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
