local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local queue = {}
local gatherEndsAt = 0
local matchStarting = false

local function getModeFromCount(count)
	if count >= MatchmakingConfig.MIN_PLAYERS.ffa then
		return "ffa"
	elseif count >= MatchmakingConfig.MIN_PLAYERS.pvp then
		return "pvp"
	end
	return "training"
end

local function isInQueue(player)
	for _, entry in queue do
		if entry.player == player then
			return true
		end
	end
	return false
end

local function removeFromQueue(player)
	for i = #queue, 1, -1 do
		if queue[i].player == player then
			table.remove(queue, i)
		end
	end
end

local function getQueueSnapshot()
	local names = {}
	for _, entry in queue do
		if entry.player.Parent then
			table.insert(names, entry.player.DisplayName)
		end
	end

	local count = #names
	local mode = getModeFromCount(count)
	local now = os.clock()
	local timeLeft = math.max(0, math.ceil(gatherEndsAt - now))

	return {
		count = count,
		max = MatchmakingConfig.MAX_QUEUE,
		mode = mode,
		modeLabel = MatchmakingConfig.MODE_LABELS[mode],
		timeLeft = timeLeft,
		players = names,
		inQueue = count > 0,
	}
end

local function broadcastQueueUpdate()
	local snapshot = getQueueSnapshot()
	for _, entry in queue do
		if entry.player.Parent then
			Remotes.QueueUpdate:FireClient(entry.player, snapshot)
		end
	end
end

local function resetGatherTimer()
	local count = #queue
	if count == 0 then
		gatherEndsAt = 0
		return
	end

	local now = os.clock()
	if count == 1 then
		gatherEndsAt = now + MatchmakingConfig.SOLO_TRAINING_WAIT
	else
		gatherEndsAt = now + MatchmakingConfig.GATHER_SECONDS
	end
end

local function startQueuedMatch()
	if matchStarting or #queue == 0 then
		return
	end

	matchStarting = true

	local players = {}
	for _, entry in queue do
		if entry.player.Parent and #players < MatchmakingConfig.MAX_QUEUE then
			table.insert(players, entry.player)
		end
	end

	queue = {}
	gatherEndsAt = 0
	broadcastQueueUpdate()

	if #players > 0 then
		Bindables.StartMatch:Fire(players)
	end

	matchStarting = false
end

local function evaluateQueue()
	if matchStarting or #queue == 0 then
		return
	end

	-- Drop disconnected players
	for i = #queue, 1, -1 do
		if not queue[i].player.Parent then
			table.remove(queue, i)
		end
	end

	if #queue == 0 then
		gatherEndsAt = 0
		return
	end

	local count = #queue
	local now = os.clock()

	if gatherEndsAt == 0 then
		resetGatherTimer()
	end

	local ready = now >= gatherEndsAt
	local mode = getModeFromCount(count)
	local minNeeded = MatchmakingConfig.MIN_PLAYERS[mode]

	if count >= minNeeded and ready then
		startQueuedMatch()
	elseif count >= MatchmakingConfig.MIN_PLAYERS.ffa then
		-- FFA threshold reached — shorten wait
		gatherEndsAt = math.min(gatherEndsAt, now + 3)
		if now >= gatherEndsAt then
			startQueuedMatch()
		end
	end

	broadcastQueueUpdate()
end

local function joinQueue(player)
	if matchStarting or isInQueue(player) then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end
	if #queue >= MatchmakingConfig.MAX_QUEUE then
		Remotes.QueueUpdate:FireClient(player, {
			count = #queue,
			max = MatchmakingConfig.MAX_QUEUE,
			mode = getModeFromCount(#queue),
			modeLabel = "Warteschlange voll",
			timeLeft = 0,
			players = {},
			inQueue = false,
			full = true,
		})
		return
	end

	table.insert(queue, { player = player, joinedAt = os.clock() })
	HubService.setQueuePhase(player)
	resetGatherTimer()
	broadcastQueueUpdate()
end

local function leaveQueue(player)
	if not isInQueue(player) then
		return
	end
	removeFromQueue(player)
	HubService.returnPlayerToHub(player)
	if #queue > 0 then
		resetGatherTimer()
	end
	broadcastQueueUpdate()
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player)
	joinQueue(player)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

Bindables.EnterArena.Event:Connect(function(player)
	joinQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
	if #queue > 0 then
		resetGatherTimer()
		broadcastQueueUpdate()
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		evaluateQueue()
	end
end)

print("[MatchmakingManager] Queue ready")
