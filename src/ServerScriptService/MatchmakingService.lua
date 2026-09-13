local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil
local started = false

local function initQueues()
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {}
	end
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local list = queues[entry.modeId]
	if list then
		for i, p in list do
			if p == player then
				table.remove(list, i)
				break
			end
		end
	end

	playerQueue[player] = nil
end

local function queuePosition(player, modeId)
	local list = queues[modeId]
	if not list then
		return 0
	end
	for i, p in list do
		if p == player then
			return i
		end
	end
	return 0
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local list = queues[entry.modeId] or {}
	local fillRemaining = nil
	if entry.modeId == "ffa" and fillTimers[entry.modeId] then
		fillRemaining = math.max(0, math.ceil(fillTimers[entry.modeId].endsAt - os.clock()))
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		position = queuePosition(player, entry.modeId),
		queued = #list,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 6,
		pending = entry.pending == true,
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueue(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllQueues()
	for player in playerQueue do
		if player.Parent then
			broadcastQueue(player)
		end
	end
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		if timer.thread then
			task.cancel(timer.thread)
		end
		fillTimers[modeId] = nil
	end
end

local function setPending(modeId, pending)
	local list = queues[modeId]
	if not list then
		return
	end
	for _, player in list do
		local entry = playerQueue[player]
		if entry and entry.modeId == modeId then
			entry.pending = pending
		end
	end
	broadcastAllQueues()
end

local function takeQueuePlayers(modeId)
	local list = queues[modeId]
	if not list or #list == 0 then
		return {}
	end

	local mode = MatchModes.get(modeId)
	local count = math.min(#list, mode.maxPlayers)
	local players = {}
	for i = 1, count do
		table.insert(players, list[i])
	end

	for _, player in players do
		removeFromQueue(player)
	end

	clearFillTimer(modeId)
	return players
end

local function tryStartMatch(modeId)
	if GameMatchState.arenaBusy then
		pendingMatch = modeId
		setPending(modeId, true)
		return false
	end

	local mode = MatchModes.get(modeId)
	local list = queues[modeId]
	if not list or #list < mode.minPlayers then
		return false
	end

	local players = takeQueuePlayers(modeId)
	if #players < mode.minPlayers then
		return false
	end

	pendingMatch = nil
	setPending(modeId, false)
	GameMatchState.arenaBusy = true
	Bindables.MatchReady:Fire(players, modeId)
	MatchmakingService.onArenaBusy()
	return true
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.useFillTimeout then
		return
	end

	clearFillTimer(modeId)

	local endsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	local thread = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers[modeId] = nil
		local list = queues[modeId]
		if list and #list >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)

	fillTimers[modeId] = { endsAt = endsAt, thread = thread }
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local list = queues[modeId]
	if not list then
		return
	end

	if #list >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if #list >= mode.minPlayers and not mode.useFillTimeout then
		tryStartMatch(modeId)
		return
	end

	if mode.useFillTimeout and #list >= mode.minPlayers and not fillTimers[modeId] then
		scheduleFillTimeout(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = {
		modeId = modeId,
		pending = GameMatchState.arenaBusy,
	}

	broadcastQueue(player)
	broadcastAllQueues()
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local modeId = MatchModes.pickQuickMatch(count)
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)

	local list = queues[modeId]
	if list and #list < (MatchModes.get(modeId).minPlayers or 1) then
		clearFillTimer(modeId)
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastAllQueues()
end

function MatchmakingService.onArenaFree()
	GameMatchState.arenaBusy = false

	if pendingMatch then
		local modeId = pendingMatch
		pendingMatch = nil
		tryStartMatch(modeId)
		return
	end

	for _, mode in MatchModes.getAll() do
		evaluateQueue(mode.id)
	end
end

function MatchmakingService.onArenaBusy()
	GameMatchState.arenaBusy = true
	for modeId in queues do
		setPending(modeId, true)
	end
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
