local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTimers = {}

local Remotes
local MatchReady
local preparePlayersForMatch
local canStartMatch = function()
	return not arenaBusy
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	fillTimers[modeId] = nil
end

local function buildQueuePayload(modeId, player)
	local mode = getModeConfig(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = MatchState.QueueStatus.Searching
	if arenaBusy then
		status = MatchState.QueueStatus.Pending
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = status,
		inQueue = true,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		playerQueue[player] = nil
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
	queues[modeId] = {}
	fillTimers[modeId] = nil
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for i = 1, math.min(count, #queue) do
		local player = queue[1]
		table.remove(queue, 1)
		playerQueue[player] = nil
		table.insert(picked, player)
	end
	fillTimers[modeId] = nil
	return picked
end

local function tryStartMatch(modeId)
	if arenaBusy or not canStartMatch() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		local players = popPlayers(modeId, mode.maxPlayers)
		arenaBusy = true
		if preparePlayersForMatch then
			preparePlayersForMatch(players)
		end
		MatchReady:Fire(players, modeId)
		return
	end

	if mode.fillTimeout > 0 then
		if not fillTimers[modeId] then
			fillTimers[modeId] = os.clock() + mode.fillTimeout
			task.delay(mode.fillTimeout, function()
				if arenaBusy or not canStartMatch() then
					broadcastQueueUpdate(modeId)
					return
				end
				local currentQueue = getQueue(modeId)
				if #currentQueue >= mode.minPlayers then
					local players = popPlayers(modeId, math.min(#currentQueue, mode.maxPlayers))
					arenaBusy = true
					if preparePlayersForMatch then
						preparePlayersForMatch(players)
					end
					MatchReady:Fire(players, modeId)
				end
			end)
		end
		return
	end

	local players = popPlayers(modeId, mode.minPlayers)
	arenaBusy = true
	if preparePlayersForMatch then
		preparePlayersForMatch(players)
	end
	MatchReady:Fire(players, modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return false
	end

	if arenaBusy and playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		return true
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.onArenaFreed()
	arenaBusy = false
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.setCanStartMatch(fn)
	canStartMatch = fn
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start(options)
	Remotes = options.remotes
	MatchReady = options.bindables.MatchReady
	preparePlayersForMatch = options.preparePlayersForMatch

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerQueue[player]
		if modeId then
			removeFromQueue(player)
			broadcastQueueUpdate(modeId)
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
