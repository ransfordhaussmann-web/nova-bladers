local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local MatchReady
local ArenaFree

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingModes = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function isValidMode(modeId)
	return MatchModes.get(modeId) ~= nil
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

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function getQueueSnapshot(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	return {
		modeId = modeId,
		label = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}
end

local function buildPlayerUpdate(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local snapshot = getQueueSnapshot(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		label = mode.label,
		count = snapshot.count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		fillSecondsLeft = nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue do
		if player.Parent then
			local status = "waiting"
			if pendingModes[modeId] and GameMatchState.isArenaBusy() then
				status = "pending"
			end
			local payload = buildPlayerUpdate(player, modeId, status)
			local timer = fillTimers[modeId]
			if timer and not timer.cancelled and timer.endsAt then
				payload.fillSecondsLeft = math.max(0, math.ceil(timer.endsAt - os.clock()))
			end
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = #queue

	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if mode.useFillTimeout then
		local timer = fillTimers[modeId]
		if timer and timer.expired then
			return true
		end
		return false
	end

	return count >= mode.minPlayers
end

local function popPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local matchPlayers = {}

	for i = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[1]
		table.remove(queue, 1)
		playerQueue[player] = nil
		table.insert(matchPlayers, player)
	end

	fillTimers[modeId] = nil
	pendingModes[modeId] = nil

	return matchPlayers
end

local function tryStartMatch(modeId)
	if not isValidMode(modeId) then
		return
	end

	if not canStartMode(modeId) then
		return
	end

	if GameMatchState.isArenaBusy() then
		pendingModes[modeId] = true
		broadcastQueueUpdate(modeId)
		return
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return
	end

	for _, player in matchPlayers do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end

	MatchReady:Fire(matchPlayers, modeId)
end

local function tryStartAllModes()
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.useFillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = { cancelled = false, expired = false }
	fillTimers[modeId] = token
	token.endsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT

	task.spawn(function()
		task.wait(MatchmakingConfig.FFA_FILL_TIMEOUT)
		if token.cancelled then
			return
		end
		token.expired = true
		tryStartMatch(modeId)
		broadcastQueueUpdate(modeId)
	end)
end

local function onQueueChanged(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]

	if mode.useFillTimeout and #queue >= mode.minPlayers and #queue < mode.maxPlayers then
		startFillTimer(modeId)
	end

	if #queue < mode.minPlayers and fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	onQueueChanged(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.onArenaFree()
	tryStartAllModes()
end

function MatchmakingService.start(hubCallbacks)
	if started then
		return
	end
	started = true

	initQueues()

	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady
	ArenaFree = bindables.ArenaFree

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not isValidMode(modeId) then
			return
		end
		if hubCallbacks and hubCallbacks.canJoinQueue and not hubCallbacks.canJoinQueue(player) then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId, timer in fillTimers do
				if timer and not timer.cancelled then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
