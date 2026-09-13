local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local handlers = {}
local queues = {}
local started = false

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function getOrCreateQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
			pending = false,
		}
	end
	return queues[modeId]
end

local function findPlayerQueue(player)
	for modeId, queue in queues do
		for _, queued in queue.players do
			if queued == player then
				return modeId, queue
			end
		end
	end
	return nil, nil
end

local function buildQueuePayload(modeId, queue)
	local mode = getMode(modeId)
	if not mode then
		return nil
	end

	local fillSecondsLeft = nil
	if queue.fillDeadline then
		fillSecondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		modeId = modeId,
		label = mode.label,
		count = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		inQueue = true,
		pending = queue.pending or GameMatchState.isBusy(),
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getOrCreateQueue(modeId)
	local payload = buildQueuePayload(modeId, queue)
	if not payload then
		return
	end

	for _, player in queue.players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearQueueDeadline(queue)
	queue.fillDeadline = nil
end

local function shouldStartMatch(modeId, queue)
	local mode = getMode(modeId)
	local count = #queue.players
	if not mode or count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if modeId == "ffa" and mode.fillTimeout then
		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + mode.fillTimeout
			return false
		end
		return os.clock() >= queue.fillDeadline
	end

	return count >= mode.minPlayers
end

local function popMatchPlayers(modeId, queue)
	local mode = getMode(modeId)
	local take = math.min(#queue.players, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, take do
		table.insert(matchPlayers, table.remove(queue.players, 1))
	end

	clearQueueDeadline(queue)
	queue.pending = false
	return matchPlayers
end

local function tryStartMatch(modeId)
	local queue = getOrCreateQueue(modeId)
	if #queue.players == 0 then
		return
	end

	if not shouldStartMatch(modeId, queue) then
		broadcastQueueUpdate(modeId)
		return
	end

	if GameMatchState.isBusy() then
		queue.pending = true
		broadcastQueueUpdate(modeId)
		return
	end

	local matchPlayers = popMatchPlayers(modeId, queue)
	if #matchPlayers == 0 then
		return
	end

	for _, player in matchPlayers do
		if handlers.leaveHubForArena then
			handlers.leaveHubForArena(player)
		end
	end

	Bindables.MatchReady:Fire(matchPlayers)
	broadcastQueueUpdate(modeId)
end

local function processAllQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.register(newHandlers)
	handlers = newHandlers
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return
	end

	if handlers.getPhase and handlers.getPhase(player) == "arena" then
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	local existingMode = findPlayerQueue(player)
	if existingMode and existingMode ~= modeId then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getOrCreateQueue(modeId)
	for _, queued in queue.players do
		if queued == player then
			broadcastQueueUpdate(modeId)
			return
		end
	end

	if #queue.players >= mode.maxPlayers then
		return
	end

	table.insert(queue.players, player)
	tryStartMatch(modeId)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId, queue = findPlayerQueue(player)
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players < getMode(modeId).minPlayers then
		clearQueueDeadline(queue)
	end
	queue.pending = false

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.onArenaFree()
	for _, queue in queues do
		queue.pending = false
	end
	processAllQueues()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			for modeId in MatchmakingConfig.MODES do
				local queue = getOrCreateQueue(modeId)
				if queue.fillDeadline and #queue.players >= getMode(modeId).minPlayers then
					tryStartMatch(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
