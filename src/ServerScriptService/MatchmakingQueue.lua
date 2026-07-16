--[[
	MatchmakingQueue — groups hub players before arena matches.
	Starts Training (solo), 1v1, or FFA based on queue size and wait time.
]]

local RunService = game:GetService("RunService")

local MatchmakingQueue = {}

local queue = {}
local onReadyCallback = nil
local canJoinFn = nil
local broadcastFn = nil
local pollConnection = nil
local isStarting = false
local lastBroadcast = 0

local CONFIG = {
	SOLO_WAIT = 8,
	PVP_WAIT = 4,
	FFA_WAIT = 3,
	MAX_WAIT = 20,
}

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local function getTargetMode(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getRequiredWait(count)
	if count >= 3 then
		return CONFIG.FFA_WAIT
	elseif count == 2 then
		return CONFIG.PVP_WAIT
	end
	return CONFIG.SOLO_WAIT
end

local function pruneQueue()
	for i = #queue, 1, -1 do
		local entry = queue[i]
		if not entry.player.Parent then
			table.remove(queue, i)
		end
	end
end

local function oldestWait()
	if #queue == 0 then
		return 0
	end
	local oldest = os.clock()
	for _, entry in queue do
		oldest = math.min(oldest, entry.joinedAt)
	end
	return os.clock() - oldest
end

function MatchmakingQueue.buildState()
	pruneQueue()
	local count = #queue
	local mode = getTargetMode(count)
	local waitSec = oldestWait()
	local requiredWait = getRequiredWait(count)
	local remaining = math.max(0, math.ceil(requiredWait - waitSec))

	return {
		inQueue = count > 0,
		count = count,
		mode = mode,
		modeLabel = MODE_LABELS[mode] or mode,
		waitSec = math.floor(waitSec),
		remainingSec = remaining,
		requiredWait = requiredWait,
		players = (function()
			local names = {}
			for _, entry in queue do
				table.insert(names, entry.player.DisplayName)
			end
			return names
		end)(),
	}
end

local function broadcastState()
	if broadcastFn then
		broadcastFn(MatchmakingQueue.buildState())
	end
end

local function shouldStart()
	local count = #queue
	if count == 0 then
		return false
	end

	local waitTime = oldestWait()
	if waitTime >= CONFIG.MAX_WAIT then
		return true
	end

	return waitTime >= getRequiredWait(count)
end

local function tryStartMatch()
	if isStarting or #queue == 0 then
		return
	end
	if not shouldStart() then
		return
	end

	isStarting = true
	local players = {}
	for _, entry in queue do
		if entry.player.Parent then
			table.insert(players, entry.player)
		end
	end
	queue = {}
	broadcastState()

	if #players > 0 and onReadyCallback then
		onReadyCallback(players)
	end
	isStarting = false
end

function MatchmakingQueue.init(opts)
	onReadyCallback = opts.onReady
	canJoinFn = opts.canJoin
	broadcastFn = opts.broadcast
	if opts.config then
		for key, value in opts.config do
			CONFIG[key] = value
		end
	end

	if pollConnection then
		pollConnection:Disconnect()
	end
	pollConnection = RunService.Heartbeat:Connect(function()
		pruneQueue()
		tryStartMatch()
		if #queue > 0 and os.clock() - lastBroadcast >= 1 then
			lastBroadcast = os.clock()
			broadcastState()
		end
	end)
end

function MatchmakingQueue.join(player)
	if canJoinFn and not canJoinFn() then
		return false, "match_active"
	end

	for i, entry in queue do
		if entry.player == player then
			return true
		end
	end

	table.insert(queue, { player = player, joinedAt = os.clock() })
	broadcastState()
	return true
end

function MatchmakingQueue.leave(player)
	for i, entry in queue do
		if entry.player == player then
			table.remove(queue, i)
			broadcastState()
			return true
		end
	end
	return false
end

function MatchmakingQueue.isQueued(player)
	for _, entry in queue do
		if entry.player == player then
			return true
		end
	end
	return false
end

function MatchmakingQueue.remove(player)
	MatchmakingQueue.leave(player)
end

function MatchmakingQueue.getQueuedPlayers()
	pruneQueue()
	local players = {}
	for _, entry in queue do
		table.insert(players, entry.player)
	end
	return players
end

return MatchmakingQueue
