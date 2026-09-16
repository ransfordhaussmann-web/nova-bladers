local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerMode = {}
local fillTimers = {}

for _, modeId in MatchModes.all() do
	queues[modeId] = {}
end

local function isValidMode(modeId)
	return MatchModes.get(modeId) ~= nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
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

	playerMode[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local pending = not MatchStateService.isAvailable()

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		inQueue = playerMode[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for _, modeId in MatchModes.all() do
		if #queues[modeId] > 0 then
			broadcastQueueUpdate(modeId)
		end
	end
end

local function pullPlayers(modeId, count)
	local queue = queues[modeId]
	local pulled = {}

	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(pulled, player)
		end
	end

	return pulled
end

local function requeuePlayers(modeId, playerList)
	for i = #playerList, 1, -1 do
		local queuedPlayer = playerList[i]
		if queuedPlayer and queuedPlayer.Parent then
			table.insert(queues[modeId], 1, queuedPlayer)
			playerMode[queuedPlayer] = modeId
		end
	end
	broadcastQueueUpdate(modeId)
end

local function startMatch(modeId, playerList)
	if not MatchStateService.isAvailable() then
		requeuePlayers(modeId, playerList)
		return
	end

	for _, queuedPlayer in playerList do
		removeFromQueue(queuedPlayer)
	end

	MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]

	if #queue < mode.minPlayers then
		return
	end

	if not MatchStateService.isAvailable() then
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.fillTimeout > 0 and #queue < mode.maxPlayers then
		if not fillTimers[modeId] then
			fillTimers[modeId] = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				local currentQueue = queues[modeId]
				if #currentQueue < mode.minPlayers then
					return
				end
				if not MatchStateService.isAvailable() then
					broadcastQueueUpdate(modeId)
					return
				end
				local count = math.min(#currentQueue, mode.maxPlayers)
				startMatch(modeId, pullPlayers(modeId, count))
			end)
		end
		broadcastQueueUpdate(modeId)
		return
	end

	local count = math.min(#queue, mode.maxPlayers)
	startMatch(modeId, pullPlayers(modeId, count))
end

local function tryStartAll()
	for _, modeId in MatchModes.all() do
		tryStartMode(modeId)
	end
end

local function joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end

	if playerMode[player] == modeId then
		return true, buildQueuePayload(modeId, player)
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	local payload = buildQueuePayload(modeId, player)
	Remotes.QueueUpdate:FireClient(player, payload)
	tryStartMode(modeId)
	return true, payload
end

local function leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = false,
		modeId = modeId,
	})
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.start(handlers)
	local remotesFolder, bindables = RemotesSetup.ensure()
	Remotes = remotesFolder
	MatchReady = bindables.MatchReady

	MatchStateService.onArenaFreed(function()
		broadcastAllQueues()
		tryStartAll()
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		local ok, payload = joinQueue(player, modeId)
		if ok and handlers.onPlayerQueued then
			handlers.onPlayerQueued(player, modeId, payload)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
		if handlers.onPlayerLeftQueue then
			handlers.onPlayerLeftQueue(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.joinQueue(player, modeId)
	return joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

return MatchmakingService
