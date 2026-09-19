local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables
local callbacks = {}
local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function countValidPlayers(queue)
	local count = 0
	for _, player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function compactQueue(modeId)
	local queue = getQueue(modeId)
	local compacted = {}
	for _, player in queue do
		if player.Parent and playerQueue[player] == modeId then
			table.insert(compacted, player)
		end
	end
	queues[modeId] = compacted
end

local function getFillDeadline(modeId)
	return fillTimers[modeId]
end

local function setFillDeadline(modeId, deadline)
	fillTimers[modeId] = deadline
end

local function clearFillDeadline(modeId)
	fillTimers[modeId] = nil
end

local function getStatusForPlayer(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	compactQueue(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local deadline = getFillDeadline(modeId)
	local fillRemaining = nil

	if deadline and count >= mode.minPlayers then
		fillRemaining = math.max(0, math.ceil(deadline - os.clock()))
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif mode.instant and count >= mode.minPlayers then
		status = "starting"
	elseif count >= mode.maxPlayers then
		status = "starting"
	elseif mode.fillTimeout and count >= mode.minPlayers and fillRemaining == 0 then
		status = "starting"
	end

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = mode.label,
		status = status,
		playersInQueue = count,
		playersNeeded = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		fillSecondsRemaining = fillRemaining,
	}
end

local function broadcastQueue(modeId)
	compactQueue(modeId)
	for _, player in getQueue(modeId) do
		if player.Parent then
			local payload = getStatusForPlayer(player, modeId)
			if payload then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	compactQueue(modeId)
	if countValidPlayers(queue) < MatchModes.get(modeId).minPlayers then
		clearFillDeadline(modeId)
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueue(modeId)
end

local function popPlayersForMatch(modeId)
	compactQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local take = math.min(count, mode.maxPlayers)

	local players = {}
	for index = 1, take do
		local player = queue[index]
		if player and player.Parent then
			table.insert(players, player)
		end
	end

	for _, player in players do
		playerQueue[player] = nil
	end

	queues[modeId] = {}
	clearFillDeadline(modeId)
	broadcastQueue(modeId)

	return players
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	compactQueue(modeId)
	local count = #getQueue(modeId)
	if count < mode.minPlayers then
		return false
	end

	if mode.instant then
		return true
	end

	if count >= mode.maxPlayers then
		return true
	end

	if mode.fillTimeout then
		local deadline = getFillDeadline(modeId)
		if deadline and os.clock() >= deadline then
			return true
		end
	end

	return false
end

local function tryStartMatches()
	if MatchStateService.isBusy() then
		broadcastAllQueues()
		return
	end

	for _, mode in MatchModes.all() do
		while not MatchStateService.isBusy() and canStartMode(mode.id) do
			local players = popPlayersForMatch(mode.id)
			if #players == 0 then
				break
			end

			for _, player in players do
				if callbacks.leaveHubForArena then
					callbacks.leaveHubForArena(player)
				end
				Remotes.QueueUpdate:FireClient(player, { inQueue = false })
			end

			Bindables.MatchReady:Fire({
				players = players,
				mode = mode.id,
			})
			break
		end
	end

	broadcastAllQueues()
end

local function ensureFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	compactQueue(modeId)
	local count = #getQueue(modeId)
	if count < mode.minPlayers then
		clearFillDeadline(modeId)
		return
	end

	if not getFillDeadline(modeId) then
		setFillDeadline(modeId, os.clock() + mode.fillTimeout)
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

	if HubService.getPhase(player) == "arena" then
		return false
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			Remotes.QueueUpdate:FireClient(player, getStatusForPlayer(player, modeId))
			return true
		end
		removePlayerFromQueue(player)
	end

	playerQueue[player] = modeId
	table.insert(getQueue(modeId), player)
	ensureFillTimer(modeId)
	broadcastQueue(modeId)
	tryStartMatches()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	removePlayerFromQueue(player)
	tryStartMatches()
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	task.defer(tryStartMatches)
end

function MatchmakingService.init(options)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	callbacks = options or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = callbacks.getActiveModeId and callbacks.getActiveModeId() or "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			for _, mode in MatchModes.all() do
				if mode.fillTimeout and getFillDeadline(mode.id) then
					compactQueue(mode.id)
					if #getQueue(mode.id) < mode.minPlayers then
						clearFillDeadline(mode.id)
					end
				end
			end
			tryStartMatches()
		end
	end)
end

return MatchmakingService
