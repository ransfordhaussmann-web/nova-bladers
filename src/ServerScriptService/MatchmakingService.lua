local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local ArenaFree = Bindables.ArenaFree

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
	return queues[modeId]
end

local function countQueuePlayers(queue)
	local count = 0
	for player in queue.players do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function getQueuePlayerList(queue)
	local list = {}
	for player in queue.players do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function pruneQueue(queue)
	local kept = {}
	for player in queue.players do
		if player.Parent and playerQueue[player] then
			table.insert(kept, player)
		end
	end
	queue.players = kept
end

local function buildUpdatePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	pruneQueue(queue)
	local count = countQueuePlayers(queue)

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		status = status,
		count = count,
		required = mode and mode.minPlayers or 1,
		max = mode and mode.maxPlayers or count,
		inQueue = true,
	}
end

local function sendQueueUpdate(player, modeId, status)
	if not player.Parent then
		return
	end
	QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId, status))
end

local function clearQueueUpdate(player)
	if not player.Parent then
		return
	end
	QueueUpdate:FireClient(player, { inQueue = false })
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	pruneQueue(queue)
	local count = countQueuePlayers(queue)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local status = "waiting"
	if GameMatchState.isBusy() then
		status = "pending"
	end

	for player in queue.players do
		if player.Parent and playerQueue[player] == modeId then
			sendQueueUpdate(player, modeId, status)
		end
	end

	if mode.fillTimeout and count >= mode.minPlayers and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + mode.fillTimeout
	end

	if count == 0 then
		queue.fillDeadline = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	pruneQueue(queue)
	if countQueuePlayers(queue) == 0 then
		queue.fillDeadline = nil
	end

	clearQueueUpdate(player)
	broadcastQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end
	if playerQueue[player] then
		removeFromQueue(player)
	end

	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	local status = GameMatchState.isBusy() and "pending" or "waiting"
	sendQueueUpdate(player, modeId, status)
	broadcastQueue(modeId)
	MatchmakingService.tryStartMatch(modeId)
end

local function launchMatch(modeId, players)
	for _, player in players do
		removeFromQueue(player)
	end

	MatchReady:Fire(players, modeId)
end

function MatchmakingService.tryStartMatch(modeId)
	if GameMatchState.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	pruneQueue(queue)
	local players = getQueuePlayerList(queue)
	local count = #players

	if count < mode.minPlayers then
		return
	end

	if count > mode.maxPlayers then
		local trimmed = {}
		for i = 1, mode.maxPlayers do
			table.insert(trimmed, players[i])
		end
		players = trimmed
	end

	if mode.fillTimeout then
		if count >= mode.maxPlayers then
			launchMatch(modeId, players)
			return
		end
		if queue.fillDeadline and os.clock() >= queue.fillDeadline then
			launchMatch(modeId, players)
			return
		end
		return
	end

	launchMatch(modeId, players)
end

local function evaluateQueues()
	for _, mode in MatchModes.all() do
		MatchmakingService.tryStartMatch(mode.id)
	end
end

local function onArenaFree()
	GameMatchState.setBusy(false)

	for _, mode in MatchModes.all() do
		broadcastQueue(mode.id)
	end
	evaluateQueues()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	ArenaFree.Event:Connect(onArenaFree)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			for _, mode in MatchModes.all() do
				local queue = getQueue(mode.id)
				pruneQueue(queue)
				if queue.fillDeadline and os.clock() >= queue.fillDeadline then
					MatchmakingService.tryStartMatch(mode.id)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
