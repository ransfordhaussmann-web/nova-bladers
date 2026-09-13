local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes
local MatchReady
local ArenaFree

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local started = false
local onMatchFormed

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end

	if #queue.players < (getModeConfig(modeId).minPlayers or 1) then
		queue.fillDeadline = nil
	end

	playerQueue[player] = nil
end

local function isPlayerPending(player)
	if not pendingMatch then
		return false
	end
	for _, pendingPlayer in pendingMatch.players do
		if pendingPlayer == player then
			return true
		end
	end
	return false
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	local isPending = isPlayerPending(player)
	if isPending then
		modeId = pendingMatch.modeId
	end

	if not modeId then
		return {
			inQueue = false,
			arenaBusy = GameMatchState.isArenaBusy(),
		}
	end

	local queue = queues[modeId]
	local mode = getModeConfig(modeId)

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queued = isPending and #pendingMatch.players or #queue.players,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		fillRemaining = queue.fillDeadline and math.max(0, queue.fillDeadline - os.clock()) or nil,
		status = isPending and "pending" or "waiting",
		arenaBusy = GameMatchState.isArenaBusy(),
	}
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] or isPlayerPending(player) then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function sendQueueUpdate(player)
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local selected = {}
	while #selected < count and #queue.players > 0 do
		local player = table.remove(queue.players, 1)
		if player.Parent then
			table.insert(selected, player)
			playerQueue[player] = nil
		end
	end
	queue.fillDeadline = nil
	return selected
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if GameMatchState.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = playerList,
		}
		broadcastQueueUpdates()
		return
	end

	pendingMatch = nil
	if onMatchFormed then
		onMatchFormed(modeId, playerList)
	end
	MatchReady:Fire({
		modeId = modeId,
		players = playerList,
	})
end

local function tryStartMode(modeId)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	if not mode or #queue.players == 0 then
		return
	end

	if #queue.players >= mode.maxPlayers then
		launchMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		return
	end

	if #queue.players >= mode.minPlayers then
		if mode.fillTimeout <= 0 or (queue.fillDeadline and os.clock() >= queue.fillDeadline) then
			launchMatch(modeId, popPlayers(modeId, math.min(#queue.players, mode.maxPlayers)))
		elseif not queue.fillDeadline then
			queue.fillDeadline = os.clock() + mode.fillTimeout
		end
	end
end

local function tryStartMatches()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	tryStartMatches()
end

local function leaveQueue(player)
	removeFromQueue(player)

	if pendingMatch then
		for index, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				table.remove(pendingMatch.players, index)
				break
			end
		end
		if #pendingMatch.players == 0 then
			pendingMatch = nil
		else
			broadcastQueueUpdates()
		end
	end

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
end

local function onArenaFree()
	if pendingMatch and not GameMatchState.isArenaBusy() then
		local match = pendingMatch
		pendingMatch = nil
		local validPlayers = {}
		for _, player in match.players do
			if player.Parent then
				table.insert(validPlayers, player)
			end
		end
		if #validPlayers > 0 then
			if onMatchFormed then
				onMatchFormed(match.modeId, validPlayers)
			end
			MatchReady:Fire({
				modeId = match.modeId,
				players = validPlayers,
			})
		end
	end

	tryStartMatches()
	broadcastQueueUpdates()
end

local function onPlayerRemoving(player)
	leaveQueue(player)
end

function MatchmakingService.setMatchFormedCallback(callback)
	onMatchFormed = callback
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	ArenaFree = Bindables.ArenaFree

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			tryStartMatches()
			broadcastQueueUpdates()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
