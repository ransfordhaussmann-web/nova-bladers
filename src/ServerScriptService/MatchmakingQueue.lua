--[[
	MatchmakingQueue — wartende Spieler sammeln und Matches nach Modus starten.
	Training (1), 1v1 PvP (2), FFA (3+).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeyConfig = require(ReplicatedStorage.NovaBladers.BeyConfig)

local MatchmakingQueue = {}

local queue = {}
local queueIndex = {}
local batchStartTime = nil
local onReadyCallback = nil
local remotes = nil

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

local function getSecondsUntilStart(count, elapsed)
	local cfg = BeyConfig.MATCHMAKING
	if count >= 3 or count == 2 then
		return math.max(0, cfg.MIN_WAIT - elapsed)
	end
	return math.max(0, cfg.SOLO_TIMEOUT - elapsed)
end

local function shouldStartMatch(count, elapsed)
	local cfg = BeyConfig.MATCHMAKING
	if count >= 3 or count == 2 then
		return elapsed >= cfg.MIN_WAIT
	end
	if count == 1 then
		return elapsed >= cfg.SOLO_TIMEOUT
	end
	return false
end

local function buildStateForPlayer(player)
	local pos = queueIndex[player]
	if not pos then
		return { inQueue = false }
	end

	local count = #queue
	local elapsed = batchStartTime and (os.clock() - batchStartTime) or 0
	local mode = getTargetMode(count)

	return {
		inQueue = true,
		position = pos,
		playersWaiting = count,
		targetMode = mode,
		modeLabel = MODE_LABELS[mode],
		secondsUntilStart = getSecondsUntilStart(count, elapsed),
		status = shouldStartMatch(count, elapsed) and "starting" or "waiting",
	}
end

local function broadcastQueueState()
	if not remotes or not remotes.QueueState then
		return
	end
	for _, player in queue do
		if player.Parent then
			remotes.QueueState:FireClient(player, buildStateForPlayer(player))
		end
	end
end

local function resetBatchTimer()
	batchStartTime = os.clock()
end

local function removePlayer(player)
	local idx = queueIndex[player]
	if not idx then
		return
	end

	table.remove(queue, idx)
	queueIndex[player] = nil
	for i, p in queue do
		queueIndex[p] = i
	end

	if #queue == 0 then
		batchStartTime = nil
	else
		resetBatchTimer()
	end

	broadcastQueueState()
end

local function popPlayersForMatch()
	local count = #queue
	local mode = getTargetMode(count)
	local take = count
	if mode == "training" then
		take = 1
	elseif mode == "pvp" then
		take = 2
	end

	local matched = {}
	for _ = 1, take do
		local player = table.remove(queue, 1)
		if player then
			queueIndex[player] = nil
			if player.Parent then
				table.insert(matched, player)
			end
		end
	end

	for i, p in queue do
		queueIndex[p] = i
	end

	if #queue == 0 then
		batchStartTime = nil
	else
		resetBatchTimer()
	end

	broadcastQueueState()
	return matched
end

function MatchmakingQueue.init(remoteFolder)
	remotes = remoteFolder
end

function MatchmakingQueue.onReady(callback)
	onReadyCallback = callback
end

function MatchmakingQueue.join(player)
	if queueIndex[player] then
		return false
	end

	table.insert(queue, player)
	queueIndex[player] = #queue

	if #queue == 1 then
		resetBatchTimer()
	end

	broadcastQueueState()
	return true
end

function MatchmakingQueue.leave(player)
	if not queueIndex[player] then
		return false
	end
	removePlayer(player)
	if remotes and remotes.QueueState then
		remotes.QueueState:FireClient(player, { inQueue = false })
	end
	return true
end

function MatchmakingQueue.isQueued(player)
	return queueIndex[player] ~= nil
end

function MatchmakingQueue.tick()
	if #queue == 0 or not batchStartTime then
		return
	end

	local count = #queue
	local elapsed = os.clock() - batchStartTime
	broadcastQueueState()

	if not shouldStartMatch(count, elapsed) then
		return
	end

	local matched = popPlayersForMatch()
	if #matched > 0 and onReadyCallback then
		onReadyCallback(matched)
	end
end

function MatchmakingQueue.startLoop()
	task.spawn(function()
		while true do
			MatchmakingQueue.tick()
			task.wait(BeyConfig.MATCHMAKING.TICK_INTERVAL)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.leave(player)
end)

return MatchmakingQueue
