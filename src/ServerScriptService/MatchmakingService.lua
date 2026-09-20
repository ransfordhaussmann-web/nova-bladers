--[[
	MatchmakingService — queue players by mode and start matches when ready.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local launching = false
local hubService
local remotes
local bindables
local initialized = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getPlayerName(player)
	return player.DisplayName or player.Name
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

	if #queue < MatchModes.get(modeId).minPlayers then
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId, forPlayer)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, getPlayerName(queuedPlayer))
		end
	end

	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == forPlayer then
			position = i
			break
		end
	end

	local fillDeadline = fillTimers[modeId]
	local fillRemaining = nil
	if fillDeadline then
		fillRemaining = math.max(0, math.ceil(fillDeadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		players = names,
		position = position,
		inQueue = forPlayer ~= nil and playerQueue[forPlayer] == modeId,
		pendingArena = MatchStateService.isArenaBusy(),
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId)
	for _, queuedPlayer in getQueue(modeId) do
		if queuedPlayer.Parent then
			remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end

	for _, player in Players:GetPlayers() do
		if hubService and hubService.getPhase(player) == "hub" and not playerQueue[player] then
			remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for _, mode in MatchModes.all() do
		broadcastQueueUpdate(mode.id)
	end
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	fillTimers[modeId] = nil
	return picked
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() or launching then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout > 0 then
		if not fillTimers[modeId] then
			fillTimers[modeId] = os.clock() + mode.fillTimeout
			broadcastQueueUpdate(modeId)
			return
		end
		if os.clock() < fillTimers[modeId] and #queue < mode.maxPlayers then
			return
		end
	end

	local playerCount = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(getQueue(modeId), player)
			playerQueue[player] = modeId
		end
		return
	end

	launching = true
	for _, player in players do
		if hubService and hubService.leaveHubForQueue then
			hubService.leaveHubForQueue(player)
		end
	end

	bindables.MatchReady:Fire({
		players = players,
		mode = modeId,
	})
	launching = false

	broadcastAllQueues()
end

local function evaluateQueues()
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		return false, "already_queued"
	end
	if hubService and hubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)
	evaluateQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	remotes.QueueUpdate:FireClient(player, {
		modeId = modeId,
		inQueue = false,
	})
	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onPlayerRemoving(player)
	if playerQueue[player] then
		local modeId = playerQueue[player]
		removeFromQueue(player)
		broadcastQueueUpdate(modeId)
		evaluateQueues()
	end
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(evaluateQueues)
end

function MatchmakingService.init(options)
	if initialized then
		return
	end
	initialized = true

	hubService = options.hubService
	remotes = options.remotes
	bindables = options.bindables

	MatchStateService.onArenaFreed(function()
		evaluateQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			for modeId, deadline in fillTimers do
				if deadline and os.clock() >= deadline then
					tryStartMatch(modeId)
				end
			end
		end
	end)

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
