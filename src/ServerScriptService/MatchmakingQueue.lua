--[[
	MatchmakingQueue — players wait in a shared queue before matches start.
	Auto-starts based on player count: Training (1), 1v1 (2), FFA (3+).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local Remotes = RemotesSetup.ensure()

local MatchmakingQueue = {}

local queue = {}
local queueRunning = false
local onMatchReady = nil
local canJoinCheck = nil

local CONFIG = {
	SOLO_TIMEOUT = 15,
	DUO_WAIT = 8,
	FFA_WAIT = 5,
	MAX_PLAYERS = 8,
	TICK = 1,
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
	if mode == "ffa" then
		return "FFA"
	elseif mode == "pvp" then
		return "1v1 PvP"
	end
	return "Training"
end

local function getWaitTime(count)
	if count >= 3 then
		return CONFIG.FFA_WAIT
	elseif count == 2 then
		return CONFIG.DUO_WAIT
	end
	return CONFIG.SOLO_TIMEOUT
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
	for i, entry in queue do
		if entry.player == player then
			table.remove(queue, i)
			return true
		end
	end
	return false
end

local function buildState(forPlayer)
	local count = #queue
	local mode = getModeFromCount(count)
	local oldestJoin = count > 0 and queue[1].joinedAt or os.clock()
	local waited = os.clock() - oldestJoin
	local waitTarget = getWaitTime(count)
	local remaining = math.max(0, math.ceil(waitTarget - waited))

	local names = {}
	for _, entry in queue do
		if entry.player.Parent then
			table.insert(names, entry.player.Name)
		end
	end

	return {
		count = count,
		mode = mode,
		modeLabel = "Modus: " .. getModeLabel(mode),
		waitRemaining = remaining,
		players = names,
		inQueue = forPlayer ~= nil and isInQueue(forPlayer),
	}
end

local function broadcastState()
	for _, entry in queue do
		if entry.player.Parent then
			Remotes.QueueState:FireClient(entry.player, buildState(entry.player))
		end
	end
end

function MatchmakingQueue.join(player)
	if canJoinCheck and not canJoinCheck() then
		return false
	end
	if isInQueue(player) then
		return false
	end
	if #queue >= CONFIG.MAX_PLAYERS then
		return false
	end

	table.insert(queue, { player = player, joinedAt = os.clock() })
	broadcastState()
	return true
end

function MatchmakingQueue.leave(player)
	if removeFromQueue(player) then
		if player.Parent then
			Remotes.QueueState:FireClient(player, { inQueue = false, count = 0 })
		end
		broadcastState()
		return true
	end
	return false
end

function MatchmakingQueue.isQueued(player)
	return isInQueue(player)
end

function MatchmakingQueue.getQueuedPlayers()
	local list = {}
	for _, entry in queue do
		if entry.player.Parent then
			table.insert(list, entry.player)
		end
	end
	return list
end

function MatchmakingQueue.onReady(callback)
	onMatchReady = callback
end

function MatchmakingQueue.setCanJoin(fn)
	canJoinCheck = fn
end

function MatchmakingQueue.start()
	if queueRunning then
		return
	end
	queueRunning = true

	task.spawn(function()
		while queueRunning do
			task.wait(CONFIG.TICK)

			for i = #queue, 1, -1 do
				if not queue[i].player.Parent then
					table.remove(queue, i)
				end
			end

			if #queue == 0 then
				continue
			end

			local count = #queue
			local oldestJoin = queue[1].joinedAt
			local waited = os.clock() - oldestJoin
			local waitTarget = getWaitTime(count)

			broadcastState()

			if waited >= waitTarget then
				local players = MatchmakingQueue.getQueuedPlayers()
				queue = {}
				if onMatchReady and #players > 0 then
					onMatchReady(players)
				end
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.leave(player)
end)

return MatchmakingQueue
