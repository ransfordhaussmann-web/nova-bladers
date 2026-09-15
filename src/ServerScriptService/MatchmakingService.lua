local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady
local queues = {}
local playerQueue = {}
local pendingMatch = nil
local started = false
local hubCallbacks = {}

local function initQueues()
	for modeId in MatchModes do
		queues[modeId] = { players = {}, fillDeadline = nil }
	end
end

local function getQuickMatchModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count >= 2 then
		return "pvp"
	end
	return "training"
end

local function buildQueueUpdate(modeId)
	local queue = queues[modeId]
	local mode = MatchModes[modeId]
	local isPending = pendingMatch ~= nil and pendingMatch.modeId == modeId
	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = isPending or MatchStateService.isArenaBusy(),
		fillDeadline = queue.fillDeadline,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueueUpdate(modeId)
	for _, player in queues[modeId].players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { modeId = nil })
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end
	playerQueue[player] = nil

	if #queue.players == 0 then
		queue.fillDeadline = nil
	end

	if pendingMatch then
		for i, queuedPlayer in pendingMatch.players do
			if queuedPlayer == player then
				table.remove(pendingMatch.players, i)
				break
			end
		end
		if #pendingMatch.players == 0 then
			pendingMatch = nil
		end
	end

	if not silent then
		broadcastQueueUpdate(modeId)
	end
	clearQueueUpdate(player)
end

local function canStartMatch(modeId)
	local queue = queues[modeId]
	local mode = MatchModes[modeId]
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout <= 0 then
		return count >= mode.minPlayers
	end
	return queue.fillDeadline ~= nil and os.clock() >= queue.fillDeadline
end

local function popPlayersForMatch(modeId)
	local queue = queues[modeId]
	local mode = MatchModes[modeId]
	local count = math.min(#queue.players, mode.maxPlayers)
	local players = {}

	for i = 1, count do
		local queuedPlayer = queue.players[i]
		table.insert(players, queuedPlayer)
		playerQueue[queuedPlayer] = nil
	end

	for _ = 1, count do
		table.remove(queue.players, 1)
	end

	if #queue.players < mode.minPlayers then
		queue.fillDeadline = nil
	end

	return players
end

local function notifyPendingMatch(modeId, players)
	for _, player in players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = modeId,
				modeLabel = MatchModes[modeId].label,
				count = #players,
				minPlayers = MatchModes[modeId].minPlayers,
				maxPlayers = MatchModes[modeId].maxPlayers,
				pending = true,
			})
		end
	end
end

local function launchMatch(modeId, players)
	for _, player in players do
		if hubCallbacks.leaveHubForArena then
			hubCallbacks.leaveHubForArena(player)
		end
	end

	MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

local function tryLaunchMatch(modeId)
	if not canStartMatch(modeId) then
		return
	end

	local players = popPlayersForMatch(modeId)
	if #players == 0 then
		return
	end

	broadcastQueueUpdate(modeId)

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = players,
		}
		notifyPendingMatch(modeId, players)
		return
	end

	launchMatch(modeId, players)
end

local function joinQueue(player, modeId)
	if not MatchModes[modeId] then
		return false
	end

	if playerQueue[player] then
		removeFromQueue(player, true)
	end

	local queue = queues[modeId]
	local mode = MatchModes[modeId]

	if #queue.players >= mode.maxPlayers then
		return false
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId

	if mode.fillTimeout > 0 and #queue.players >= mode.minPlayers and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + mode.fillTimeout
	end

	broadcastQueueUpdate(modeId)
	tryLaunchMatch(modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	return joinQueue(player, modeId)
end

function MatchmakingService.joinQuickMatch(player)
	return joinQueue(player, getQuickMatchModeId())
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start(callbacks)
	if started then
		return
	end
	started = true
	hubCallbacks = callbacks or {}

	local _, bindables = RemotesSetup.ensure()
	Remotes = ReplicatedStorage.NovaBladers.Remotes
	MatchReady = bindables.MatchReady
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		removeFromQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			for modeId in MatchModes do
				if canStartMatch(modeId) then
					tryLaunchMatch(modeId)
				end
			end

			if pendingMatch and not MatchStateService.isArenaBusy() then
				local match = pendingMatch
				pendingMatch = nil
				launchMatch(match.modeId, match.players)
			end
		end
	end)
end

return MatchmakingService
