--[[
	MatchmakingQueue — waits for opponents before starting a match.
	MIN_WAIT: earliest start with 2+ players. MAX_WAIT: force start (solo training).
]]

local MatchmakingQueue = {}

local MIN_WAIT = 3
local MAX_WAIT = 18

local queue = {}
local queueSet = {}
local queueStartTime = nil
local popping = false

local remotes = nil
local onStartMatch = nil

local function getActivePlayers()
	local list = {}
	for _, player in queue do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function getModeLabel(count)
	if count >= 3 then
		return "FFA"
	elseif count == 2 then
		return "1v1 PvP"
	end
	return "Training"
end

local function pruneQueue()
	local nextQueue = {}
	local nextSet = {}
	for _, player in queue do
		if player.Parent then
			table.insert(nextQueue, player)
			nextSet[player] = true
		end
	end
	queue = nextQueue
	queueSet = nextSet
	if #queue == 0 then
		queueStartTime = nil
	end
end

local function broadcastStatus()
	if not remotes then
		return
	end

	pruneQueue()
	local players = getActivePlayers()
	local count = #players
	if count == 0 then
		return
	end

	local elapsed = queueStartTime and (os.clock() - queueStartTime) or 0
	local waitLeft
	if count >= 2 and elapsed < MIN_WAIT then
		waitLeft = MIN_WAIT - elapsed
	else
		waitLeft = MAX_WAIT - elapsed
	end
	waitLeft = math.max(0, waitLeft)

	local payload = {
		inQueue = true,
		playersInQueue = count,
		waitSeconds = math.ceil(waitLeft),
		minWait = MIN_WAIT,
		maxWait = MAX_WAIT,
		mode = getModeLabel(count),
	}

	for _, player in players do
		remotes.QueueStatus:FireClient(player, payload)
	end
end

local function resetQueue()
	queue = {}
	queueSet = {}
	queueStartTime = nil
end

local function tryStartMatch()
	if popping or not queueStartTime then
		return
	end

	pruneQueue()
	local players = getActivePlayers()
	local count = #players
	if count == 0 then
		resetQueue()
		return
	end

	local elapsed = os.clock() - queueStartTime
	local shouldStart = false

	if elapsed >= MAX_WAIT then
		shouldStart = true
	elseif elapsed >= MIN_WAIT and count >= 2 then
		shouldStart = true
	end

	if not shouldStart then
		return
	end

	popping = true
	local matchPlayers = players
	resetQueue()

	if onStartMatch then
		onStartMatch(matchPlayers)
	end

	popping = false
end

function MatchmakingQueue.init(remotesFolder, startCallback)
	remotes = remotesFolder
	onStartMatch = startCallback

	remotes.LeaveQueue.OnServerEvent:Connect(function(player)
		MatchmakingQueue.leave(player)
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			if queueStartTime then
				broadcastStatus()
				tryStartMatch()
			end
		end
	end)
end

function MatchmakingQueue.join(player)
	if queueSet[player] then
		broadcastStatus()
		return
	end

	table.insert(queue, player)
	queueSet[player] = true
	if not queueStartTime then
		queueStartTime = os.clock()
	end
	broadcastStatus()
end

function MatchmakingQueue.leave(player)
	if not queueSet[player] then
		return
	end

	queueSet[player] = nil
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	if remotes then
		remotes.QueueStatus:FireClient(player, { inQueue = false })
	end

	if #queue == 0 then
		resetQueue()
	else
		broadcastStatus()
	end
end

function MatchmakingQueue.isQueued(player)
	return queueSet[player] == true
end

function MatchmakingQueue.remove(player)
	MatchmakingQueue.leave(player)
end

return MatchmakingQueue
