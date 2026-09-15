local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
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

local function countValidPlayers(list)
	local count = 0
	for _, player in list do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local cleaned = {}
	for _, player in queue do
		if player.Parent and playerQueue[player] == modeId then
			table.insert(cleaned, player)
		end
	end
	queues[modeId] = cleaned
	return cleaned
end

local function buildUpdate(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = pruneQueue(modeId)
	local playersInQueue = countValidPlayers(queue)
	local playersNeeded = mode.minPlayers

	local eta
	local timer = fillTimers[modeId]
	if timer and timer.endsAt then
		eta = math.max(0, math.ceil(timer.endsAt - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		playersInQueue = playersInQueue,
		playersNeeded = playersNeeded,
		eta = eta,
	}
end

local function sendUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId)
	local queue = pruneQueue(modeId)
	local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
	for _, player in queue do
		sendUpdate(player, buildUpdate(player, modeId, status))
	end
end

local function broadcastAllQueues()
	for _, modeId in MatchModes.all() do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	clearFillTimer(modeId)
	fillTimers[modeId] = {
		endsAt = os.clock() + mode.fillTimeout,
		token = (fillTimers[modeId] and fillTimers[modeId].token or 0) + 1,
	}

	local token = fillTimers[modeId].token
	task.delay(mode.fillTimeout, function()
		local timer = fillTimers[modeId]
		if not timer or timer.token ~= token then
			return
		end
		clearFillTimer(modeId)
		MatchmakingService.tryStart(modeId)
	end)
end

local function removeFromQueue(player)
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

	if #queue < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	sendUpdate(player, { inQueue = false })
	broadcastQueue(modeId)
end

local function popPlayers(modeId, count)
	local queue = pruneQueue(modeId)
	local picked = {}
	for index = 1, math.min(count, #queue) do
		table.insert(picked, queue[index])
	end

	queues[modeId] = {}
	clearFillTimer(modeId)

	for _, player in picked do
		playerQueue[player] = nil
		sendUpdate(player, { inQueue = false })
	end

	return picked
end

function MatchmakingService.tryStart(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = pruneQueue(modeId)
	local count = #queue
	if count < mode.minPlayers then
		return false
	end

	local takeCount = math.min(count, mode.maxPlayers)
	local players = popPlayers(modeId, takeCount)
	if #players < mode.minPlayers then
		return false
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = players,
	})

	broadcastAllQueues()
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		return false, "already_queued"
	end
	if MatchStateService.isArenaBusy() and MatchModes.get(modeId).minPlayers == 1 then
		-- Training can still queue while busy; it waits as pending.
	end

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
	sendUpdate(player, buildUpdate(player, modeId, status))
	broadcastQueue(modeId)

	local mode = MatchModes.get(modeId)
	if #queue >= mode.maxPlayers then
		MatchmakingService.tryStart(modeId)
	elseif #queue >= mode.minPlayers then
		if mode.fillTimeout then
			if not fillTimers[modeId] then
				startFillTimer(modeId)
				broadcastQueue(modeId)
			end
		else
			MatchmakingService.tryStart(modeId)
		end
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		for _, modeId in MatchModes.all() do
			MatchmakingService.tryStart(modeId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			for _, modeId in MatchModes.all() do
				if #getQueue(modeId) > 0 then
					broadcastQueue(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
