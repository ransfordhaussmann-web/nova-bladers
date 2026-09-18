local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil
local callbacks = {}

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
	if fillTimers[modeId] then
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local pending = pendingMatch ~= nil and pendingMatch.modeId == modeId

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending or MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllQueues()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			broadcastQueueUpdate(player)
		end
	end
	if callbacks.onQueueChanged then
		callbacks.onQueueChanged()
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	fillTimers[modeId] = nil
	return taken
end

local function startMatch(modeId, playerList)
	pendingMatch = nil
	fillTimers[modeId] = nil

	for _, player in playerList do
		removeFromQueue(player)
	end

	if callbacks.leaveHubForArena then
		for _, player in playerList do
			callbacks.leaveHubForArena(player)
		end
	end

	task.delay(MatchmakingConfig.MATCH_READY_DELAY, function()
		if MatchReady then
			MatchReady:Fire({
				modeId = modeId,
				players = playerList,
			})
		end
	end)
end

local function tryStartMode(modeId)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	if mode.fillTimeout > 0 and #queue < mode.maxPlayers then
		if not fillTimers[modeId] then
			fillTimers[modeId] = os.clock()
			task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				if not MatchStateService.isArenaBusy() then
					tryStartMode(modeId)
				else
					pendingMatch = { modeId = modeId }
					broadcastAllQueues()
				end
			end)
		end
		return false
	end

	local players = takePlayersFromQueue(modeId, mode.maxPlayers)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(getQueue(modeId), player)
			playerQueue[player] = modeId
		end
		return false
	end

	startMatch(modeId, players)
	broadcastAllQueues()
	return true
end

local function tryStartAnyPending()
	if MatchStateService.isArenaBusy() then
		return
	end

	if pendingMatch then
		local modeId = pendingMatch.modeId
		pendingMatch = nil
		tryStartMode(modeId)
		return
	end

	for _, mode in { MatchModes.training, MatchModes.pvp, MatchModes.ffa } do
		if tryStartMode(mode.id) then
			return
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] == modeId then
		broadcastQueueUpdate(player)
		return true
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(player)
	broadcastAllQueues()

	if MatchStateService.isArenaBusy() then
		pendingMatch = { modeId = modeId }
		return true, "pending"
	end

	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	broadcastQueueUpdate(player)
	broadcastAllQueues()

	if pendingMatch and pendingMatch.modeId == modeId and #getQueue(modeId) < MatchModes.get(modeId).minPlayers then
		pendingMatch = nil
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.init(opts)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	callbacks = opts or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingConfig.DEFAULT_MODE
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		tryStartAnyPending()
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
