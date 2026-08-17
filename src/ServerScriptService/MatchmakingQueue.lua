--[[
	MatchmakingQueue — gathers players before a match starts.
	Solo: short wait for more players, then Training.
	2 players: 3s countdown → 1v1 PvP.
	3+ players: 3s countdown → FFA.
]]

local Players = game:GetService("Players")

local MatchmakingQueue = {}

local SOLO_WAIT_SECONDS = 5
local READY_COUNTDOWN_SECONDS = 3
local TICK_INTERVAL = 0.25

local queue = {}
local queueSet = {}
local readyAt = nil
local onMatchReady = nil
local broadcastUpdate = nil
local tickLoop = nil

local function getModeForCount(count)
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

local function pruneQueue()
	local i = 1
	while i <= #queue do
		local player = queue[i]
		if not player.Parent then
			queueSet[player] = nil
			table.remove(queue, i)
		else
			i += 1
		end
	end
end

local function buildPayload(forPlayer)
	pruneQueue()
	local names = {}
	for _, player in queue do
		table.insert(names, player.Name)
	end

	local count = #queue
	local mode = getModeForCount(count)
	local countdown = nil
	if readyAt then
		countdown = math.max(0, math.ceil(readyAt - os.clock()))
	end

	return {
		inQueue = forPlayer and queueSet[forPlayer] == true,
		waiting = count,
		mode = mode,
		modeLabel = getModeLabel(mode),
		players = names,
		countdown = countdown,
		minPlayers = mode == "ffa" and 3 or (mode == "pvp" and 2 or 1),
	}
end

local function notifyAll()
	if not broadcastUpdate then
		return
	end
	pruneQueue()
	for _, player in queue do
		broadcastUpdate(player, buildPayload(player))
	end
end

local function recomputeReadyTime()
	pruneQueue()
	local count = #queue
	if count == 0 then
		readyAt = nil
		return
	end

	if count >= 2 then
		if not readyAt or readyAt - os.clock() > READY_COUNTDOWN_SECONDS then
			readyAt = os.clock() + READY_COUNTDOWN_SECONDS
		end
	else
		readyAt = os.clock() + SOLO_WAIT_SECONDS
	end
end

local function tryStartMatch()
	pruneQueue()
	if #queue == 0 or not readyAt or os.clock() < readyAt then
		return
	end

	local playerList = {}
	for _, player in queue do
		table.insert(playerList, player)
	end

	for _, player in playerList do
		queueSet[player] = nil
	end
	table.clear(queue)
	readyAt = nil

	if onMatchReady then
		onMatchReady(playerList)
	end
end

function MatchmakingQueue.init(options)
	onMatchReady = options.onMatchReady
	broadcastUpdate = options.onQueueUpdate

	if tickLoop then
		return
	end

	task.spawn(function()
		while true do
			task.wait(TICK_INTERVAL)
			if #queue > 0 then
				recomputeReadyTime()
				notifyAll()
				tryStartMatch()
			end
		end
	end)
end

function MatchmakingQueue.join(player)
	if queueSet[player] then
		notifyAll()
		return
	end

	table.insert(queue, player)
	queueSet[player] = true
	recomputeReadyTime()
	notifyAll()
end

function MatchmakingQueue.leave(player)
	if not queueSet[player] then
		return false
	end

	queueSet[player] = nil
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	recomputeReadyTime()
	notifyAll()
	return true
end

function MatchmakingQueue.isQueued(player)
	return queueSet[player] == true
end

function MatchmakingQueue.remove(player)
	MatchmakingQueue.leave(player)
end

function MatchmakingQueue.getStatus(player)
	return buildPayload(player)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.remove(player)
end)

return MatchmakingQueue
