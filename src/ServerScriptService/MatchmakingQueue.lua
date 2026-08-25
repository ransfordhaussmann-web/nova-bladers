--[[
	MatchmakingQueue — gathers players at the arena portal before a match starts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeyConfig = require(ReplicatedStorage.NovaBladers.BeyConfig)

local MatchmakingQueue = {}

local queue = {}
local queueSet = {}
local gatherStartedAt = 0
local gatherToken = 0
local tickerActive = false
local callbacks = {}

local function getModeFromCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getModeLabel(mode)
	if mode == "ffa" then
		return "FFA"
	elseif mode == "pvp" then
		return "1v1 PvP"
	end
	return "Training"
end

local function getActivePlayers()
	local active = {}
	for _, player in queue do
		if player.Parent then
			table.insert(active, player)
		end
	end
	return active
end

local function getGatherDeadline(count)
	local elapsed = os.clock() - gatherStartedAt
	if count <= 1 then
		return gatherStartedAt + BeyConfig.QUEUE_SOLO_START_SECONDS
	end
	return gatherStartedAt + BeyConfig.QUEUE_GATHER_SECONDS
end

local function buildPayload()
	local players = getActivePlayers()
	local count = #players
	local mode = getModeFromCount(count)
	local deadline = gatherStartedAt > 0 and getGatherDeadline(count) or 0
	local remaining = math.max(0, deadline - os.clock())

	local names = {}
	for _, player in players do
		table.insert(names, player.DisplayName)
	end

	return {
		inQueue = true,
		playerCount = count,
		playerNames = names,
		mode = mode,
		modeLabel = getModeLabel(mode),
		countdown = math.ceil(remaining),
	}
end

function MatchmakingQueue.setCallbacks(cbs)
	callbacks = cbs or {}
end

function MatchmakingQueue.isQueued(player)
	return queueSet[player] == true
end

function MatchmakingQueue.hasPlayers()
	return #getActivePlayers() > 0
end

function MatchmakingQueue.broadcast()
	local payload = buildPayload()
	if callbacks.onQueueUpdate then
		for _, player in getActivePlayers() do
			callbacks.onQueueUpdate(player, payload)
		end
	end
end

local function stopTicker()
	tickerActive = false
end

local function resetGather()
	queue = {}
	table.clear(queueSet)
	gatherStartedAt = 0
	gatherToken += 1
	stopTicker()
end

local function tryStartMatch()
	local players = getActivePlayers()
	if #players == 0 then
		resetGather()
		return
	end

	local token = gatherToken
	resetGather()

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players)
	end
end

local function shouldStartNow(count, remaining)
	if count <= 0 then
		return false
	end
	if count >= 3 then
		return remaining <= BeyConfig.QUEUE_GATHER_SECONDS - BeyConfig.QUEUE_READY_COUNTDOWN
	end
	if count == 2 and remaining <= BeyConfig.QUEUE_GATHER_SECONDS - BeyConfig.QUEUE_READY_COUNTDOWN then
		return true
	end
	if count == 1 and remaining <= 0 then
		return true
	end
	return remaining <= 0
end

local function startTicker()
	stopTicker()
	local token = gatherToken
	tickerActive = true
	task.spawn(function()
		while tickerActive and token == gatherToken do
			-- Prune disconnected players
			local pruned = false
			for i = #queue, 1, -1 do
				if not queue[i].Parent then
					queueSet[queue[i]] = nil
					table.remove(queue, i)
					pruned = true
				end
			end

			local players = getActivePlayers()
			if #players == 0 then
				resetGather()
				return
			end

			local remaining = getGatherDeadline(#players) - os.clock()
			MatchmakingQueue.broadcast()

			if shouldStartNow(#players, remaining) then
				tryStartMatch()
				return
			end

			task.wait(1)
		end
	end)
end

function MatchmakingQueue.addPlayer(player)
	if queueSet[player] then
		MatchmakingQueue.broadcast()
		return
	end

	table.insert(queue, player)
	queueSet[player] = true

	if gatherStartedAt == 0 then
		gatherStartedAt = os.clock()
		gatherToken += 1
		startTicker()
	end

	MatchmakingQueue.broadcast()
end

function MatchmakingQueue.removePlayer(player)
	if not queueSet[player] then
		return
	end

	queueSet[player] = nil
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
			break
		end
	end

	if callbacks.onPlayerLeft then
		callbacks.onPlayerLeft(player)
	end

	if #getActivePlayers() == 0 then
		resetGather()
		return
	end

	MatchmakingQueue.broadcast()
end

function MatchmakingQueue.clear()
	resetGather()
end

return MatchmakingQueue
