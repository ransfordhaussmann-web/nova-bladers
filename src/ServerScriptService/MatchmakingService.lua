local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local Remotes
local Bindables

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
			fillToken = 0,
		}
	end
end

local function buildUpdatePayload(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = #queue.players
	local arenaBusy = GameMatchState.isArenaBusy()

	local status = "waiting"
	if count >= config.minPlayers then
		if arenaBusy then
			status = "pending"
		elseif config.fillTimeout > 0 and queue.fillDeadline then
			status = "filling"
		else
			status = "ready"
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		playersInQueue = count,
		playersNeeded = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
		fillTimeLeft = queue.fillDeadline and math.max(0, math.ceil(queue.fillDeadline - os.clock())) or nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildUpdatePayload(modeId)
	for _, player in queues[modeId].players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearPlayerFromQueues(player)
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
	if #queue.players < config.minPlayers then
		queue.fillDeadline = nil
		queue.fillToken += 1
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate(modeId)
end

local function tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]

	if GameMatchState.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	if #queue.players < config.minPlayers then
		return
	end

	if config.fillTimeout > 0 and queue.fillDeadline and os.clock() < queue.fillDeadline then
		return
	end

	local matchPlayers = {}
	local take = math.min(#queue.players, config.maxPlayers)
	for i = 1, take do
		table.insert(matchPlayers, queue.players[i])
	end

	for i = 1, take do
		local queuedPlayer = queue.players[1]
		table.remove(queue.players, 1)
		playerQueue[queuedPlayer] = nil
		Remotes.QueueUpdate:FireClient(queuedPlayer, { inQueue = false, status = "starting" })
	end
	queue.fillDeadline = nil
	queue.fillToken += 1

	Bindables.MatchReady:Fire(matchPlayers, modeId)
	broadcastQueueUpdate(modeId)
end

local function scheduleFillTimeout(modeId)
	local config = getModeConfig(modeId)
	if config.fillTimeout <= 0 then
		tryStartMatch(modeId)
		return
	end

	local queue = queues[modeId]
	queue.fillToken += 1
	local token = queue.fillToken
	queue.fillDeadline = os.clock() + config.fillTimeout
	broadcastQueueUpdate(modeId)

	task.delay(config.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		tryStartMatch(modeId)
	end)
end

local function onPlayerJoinedQueue(player, modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]

	if #queue.players >= config.maxPlayers then
		return false
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId))
	broadcastQueueUpdate(modeId)

	if #queue.players >= config.minPlayers then
		if config.fillTimeout > 0 and not queue.fillDeadline then
			scheduleFillTimeout(modeId)
		else
			tryStartMatch(modeId)
		end
	end

	return true
end

function MatchmakingService.start(remotes, bindables)
	Remotes = remotes
	Bindables = bindables
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
			return
		end
		clearPlayerFromQueues(player)
		onPlayerJoinedQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		clearPlayerFromQueues(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearPlayerFromQueues(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		GameMatchState.setArenaBusy(false)
		for modeId in queues do
			local config = getModeConfig(modeId)
			local queue = queues[modeId]
			if #queue.players >= config.minPlayers then
				if config.fillTimeout > 0 and not queue.fillDeadline then
					scheduleFillTimeout(modeId)
				else
					tryStartMatch(modeId)
				end
			else
				broadcastQueueUpdate(modeId)
			end
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
		return false
	end
	clearPlayerFromQueues(player)
	return onPlayerJoinedQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	clearPlayerFromQueues(player)
end

function MatchmakingService.getActiveModeId()
	return MatchmakingConfig.getDefaultModeId(#Players:GetPlayers())
end

return MatchmakingService
