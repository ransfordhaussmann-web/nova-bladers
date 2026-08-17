--[[
	MatchmakingQueue — gathers players before a match starts.
	Players join via the arena portal; after a short gather window the batch
	is handed to GameManager.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeyConfig = require(ReplicatedStorage.NovaBladers.BeyConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local MatchmakingQueue = {}

local queue = {}
local gatherToken = 0
local gatherEndsAt = 0
local matchLocked = false
local onMatchReadyCallback = nil

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local function getModeFromCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getModeLabel(mode)
	return MODE_LABELS[mode] or "Training"
end

local function findEntryIndex(player)
	for i, entry in queue do
		if entry.player == player then
			return i
		end
	end
	return nil
end

local function clearQueueState(player)
	if player.Parent then
		Remotes.QueueState:FireClient(player, { inQueue = false })
	end
end

local function buildStateForPlayer(index)
	local total = #queue
	local mode = getModeFromCount(total)
	local secondsLeft = 0
	if gatherEndsAt > 0 then
		secondsLeft = math.max(0, math.ceil(gatherEndsAt - os.clock()))
	end

	return {
		inQueue = true,
		position = index,
		total = total,
		mode = mode,
		modeLabel = getModeLabel(mode),
		secondsLeft = secondsLeft,
	}
end

local function broadcastState()
	for index, entry in queue do
		local player = entry.player
		if player.Parent then
			Remotes.QueueState:FireClient(player, buildStateForPlayer(index))
		end
	end
end

local function popReadyPlayers()
	local players = {}
	for _, entry in queue do
		if entry.player.Parent then
			table.insert(players, entry.player)
		end
	end

	queue = {}
	gatherEndsAt = 0

	for _, player in players do
		clearQueueState(player)
	end

	return players
end

local function finishGather(token)
	if token ~= gatherToken or matchLocked then
		return
	end

	local players = popReadyPlayers()
	gatherToken += 1

	if #players == 0 then
		return
	end

	matchLocked = true
	if onMatchReadyCallback then
		onMatchReadyCallback(players, getModeFromCount(#players))
	end
end

local function startGatherWindow()
	gatherToken += 1
	local token = gatherToken
	gatherEndsAt = os.clock() + BeyConfig.QUEUE_GATHER_SECONDS
	broadcastState()

	task.spawn(function()
		while token == gatherToken and not matchLocked do
			if os.clock() >= gatherEndsAt then
				finishGather(token)
				return
			end
			broadcastState()
			task.wait(BeyConfig.QUEUE_TICK_INTERVAL)
		end
	end)
end

function MatchmakingQueue.isInQueue(player)
	return findEntryIndex(player) ~= nil
end

function MatchmakingQueue.join(player)
	if matchLocked then
		return false
	end

	local existing = findEntryIndex(player)
	if existing then
		broadcastState()
		return true
	end

	table.insert(queue, {
		player = player,
		joinedAt = os.clock(),
	})

	if #queue == 1 then
		startGatherWindow()
	else
		broadcastState()
	end

	return true
end

function MatchmakingQueue.leave(player)
	local index = findEntryIndex(player)
	if not index then
		return false
	end

	table.remove(queue, index)
	clearQueueState(player)

	if #queue == 0 then
		gatherToken += 1
		gatherEndsAt = 0
	else
		broadcastState()
	end

	return true
end

function MatchmakingQueue.setMatchLocked(locked)
	matchLocked = locked
	if not locked and #queue > 0 then
		startGatherWindow()
	end
end

function MatchmakingQueue.onMatchReady(callback)
	onMatchReadyCallback = callback
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.leave(player)
end)

return MatchmakingQueue
