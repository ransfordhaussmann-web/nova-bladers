local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local fillTimers = {}

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
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function queueSize(modeId)
	return #getQueue(modeId)
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local size = queueSize(modeId)
	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = size,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = fillTimers[modeId] ~= nil and MatchmakingConfig.FFA_FILL_TIMEOUT or nil,
		pending = pendingMatch ~= nil and MatchStateService.isBusy(),
		inQueue = playerQueue[player] == modeId,
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

local function notifyLeftQueue(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function leaveHubForPlayers(playerList)
	for _, player in playerList do
		if callbacks.onPlayerLeaveHub then
			callbacks.onPlayerLeaveHub(player)
		end
	end
end

local function clearQueuesForPlayers(playerList)
	for _, player in playerList do
		removeFromQueue(player)
		notifyLeftQueue(player)
	end
end

local function startMatch(playerList, modeId)
	pendingMatch = nil
	clearQueuesForPlayers(playerList)
	leaveHubForPlayers(playerList)
	MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId, fromTimer)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	if count > mode.maxPlayers then
		return
	end

	local ready = count >= mode.maxPlayers
		or (mode.fillTimeout == nil and count >= mode.minPlayers)
		or (fromTimer and count >= mode.minPlayers)

	if ready then
		if fillTimers[modeId] then
			task.cancel(fillTimers[modeId])
			fillTimers[modeId] = nil
		end

		local roster = {}
		for i = 1, math.min(count, mode.maxPlayers) do
			table.insert(roster, queue[i])
		end

		if MatchStateService.isBusy() then
			pendingMatch = { players = roster, modeId = modeId }
			for _, player in roster do
				if player.Parent then
					Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
				end
			end
			return
		end

		startMatch(roster, modeId)
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId, true)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	if mode.fillTimeout and queueSize(modeId) >= mode.minPlayers then
		startFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	notifyLeftQueue(player)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.init(opts)
	callbacks = opts or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		if pendingMatch then
			local match = pendingMatch
			pendingMatch = nil
			startMatch(match.players, match.modeId)
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
