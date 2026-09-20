local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(ReplicatedStorage.NovaBladers.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local HubService

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local tickRunning = false
local pendingMatch = nil

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[entry.modeId] then
		local modeDef = MatchModes.get(entry.modeId)
		if modeDef and not modeDef.instantStart and #queue < modeDef.minPlayers then
			fillTimers[entry.modeId] = nil
		end
	end
end

local function buildQueuePayload(modeId, forPlayer)
	local modeDef = MatchModes.get(modeId)
	local queued = queues[modeId]
	local names = {}
	for _, p in queued do
		if p.Parent then
			table.insert(names, p.DisplayName)
		end
	end

	local position = 0
	for i, p in queued do
		if p == forPlayer then
			position = i
			break
		end
	end

	local pending = MatchStateService.isArenaBusy()
	local fillRemaining = nil
	if fillTimers[modeId] then
		fillRemaining = math.max(0, math.ceil(fillTimers[modeId] - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = modeDef.label,
		queuedCount = #queued,
		minPlayers = modeDef.minPlayers,
		maxPlayers = modeDef.maxPlayers,
		position = position,
		playerNames = names,
		pending = pending,
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		if player.Parent and playerQueue[player] then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function tryStartMatch(modeId)
	local modeDef = MatchModes.get(modeId)
	if not modeDef then
		return
	end

	local queue = queues[modeId]
	if #queue < modeDef.minPlayers then
		return
	end

	if not modeDef.instantStart then
		if not fillTimers[modeId] then
			return
		end
		if os.clock() < fillTimers[modeId] and #queue < modeDef.maxPlayers then
			return
		end
	end

	if MatchStateService.isArenaBusy() then
		if not pendingMatch or pendingMatch.modeId ~= modeId then
			pendingMatch = {
				modeId = modeId,
				players = table.clone(queue),
			}
		end
		broadcastAllQueues()
		return
	end

	local matchPlayers = {}
	local takeCount = math.min(#queue, modeDef.maxPlayers)
	for i = 1, takeCount do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	fillTimers[modeId] = nil
	pendingMatch = nil

	MatchStateService.setArenaBusy(true)
	Bindables.MatchReady:Fire(matchPlayers, modeId)
end

local function evaluateQueue(modeId)
	local modeDef = MatchModes.get(modeId)
	local queue = queues[modeId]

	if #queue < modeDef.minPlayers then
		return
	end

	if modeDef.instantStart then
		if #queue >= modeDef.maxPlayers then
			tryStartMatch(modeId)
		elseif modeId == MatchModes.TRAINING and #queue >= 1 then
			tryStartMatch(modeId)
		elseif modeId == MatchModes.PVP and #queue >= 2 then
			tryStartMatch(modeId)
		end
		return
	end

	if not fillTimers[modeId] then
		fillTimers[modeId] = os.clock() + (modeDef.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT)
	end

	if #queue >= modeDef.maxPlayers or os.clock() >= fillTimers[modeId] then
		tryStartMatch(modeId)
	end
end

local function evaluateAllQueues()
	for modeId in queues do
		evaluateQueue(modeId)
	end

	if pendingMatch and not MatchStateService.isArenaBusy() then
		local modeId = pendingMatch.modeId
		local queue = queues[modeId]
		if #queue >= MatchModes.get(modeId).minPlayers then
			tryStartMatch(modeId)
		else
			pendingMatch = nil
		end
	end
end

local function startTickLoop()
	if tickRunning then
		return
	end
	tickRunning = true

	task.spawn(function()
		while tickRunning do
			evaluateAllQueues()
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player].modeId == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	if HubService and HubService.getPhase(player) == "arena" then
		return false, "in_match"
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId }

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)
	evaluateQueue(modeId)

	return true
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { modeId = nil })
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.init(hubServiceRef)
	HubService = hubServiceRef
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onMatchEnded(function()
		MatchStateService.setArenaBusy(false)
		task.defer(evaluateAllQueues)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	startTickLoop()
end

return MatchmakingService
