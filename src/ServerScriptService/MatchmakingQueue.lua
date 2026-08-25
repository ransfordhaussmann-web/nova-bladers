--[[
	Matchmaking queue: players wait at the arena portal until enough fighters
	are ready (FFA 3+, PvP 2 after timeout, Training solo after timeout).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeyConfig = require(ReplicatedStorage.NovaBladers.BeyConfig)

local MatchmakingQueue = {}

local queue = {}
local remotes = nil
local onMatchReady = nil
local canStartMatch = nil
local tickLoop = nil

local cfg = BeyConfig.MATCH_QUEUE

local function getTargetMode(count)
	if count >= cfg.FFA_MIN then
		return "ffa"
	elseif count >= 2 then
		return "pvp"
	end
	return "training"
end

local function modeLabel(modeId)
	if modeId == "ffa" then
		return "FFA"
	elseif modeId == "pvp" then
		return "1v1 PvP"
	end
	return "Training"
end

local function pruneQueue()
	for i = #queue, 1, -1 do
		local entry = queue[i]
		if not entry.player.Parent then
			table.remove(queue, i)
		end
	end
end

local function waitUntilStart(entry)
	return os.clock() - entry.joinedAt
end

local function buildPayload(entry)
	pruneQueue()
	local count = #queue
	local targetMode = getTargetMode(count)
	local oldestWait = count > 0 and waitUntilStart(queue[1]) or 0
	local waitRemaining = 0

	if targetMode == "ffa" then
		waitRemaining = 0
	elseif targetMode == "pvp" then
		waitRemaining = math.max(0, cfg.PVP_TIMEOUT - oldestWait)
	else
		waitRemaining = math.max(0, cfg.TRAINING_TIMEOUT - oldestWait)
	end

	return {
		queued = true,
		count = count,
		targetMode = targetMode,
		modeLabel = ("Modus: %s"):format(modeLabel(targetMode)),
		waitRemaining = math.ceil(waitRemaining),
	}
end

local function broadcastUpdate()
	if not remotes then
		return
	end
	pruneQueue()
	for _, entry in queue do
		if entry.player.Parent then
			remotes.MatchQueueUpdate:FireClient(entry.player, buildPayload(entry))
		end
	end
end

local function popPlayers(n)
	local players = {}
	for _ = 1, math.min(n, #queue) do
		local entry = table.remove(queue, 1)
		if entry and entry.player.Parent then
			table.insert(players, entry.player)
			remotes.MatchQueueUpdate:FireClient(entry.player, { queued = false })
		end
	end
	return players
end

local function tryStartMatch()
	if not canStartMatch or not canStartMatch() then
		return false
	end

	pruneQueue()
	if #queue == 0 then
		return false
	end

	local oldestWait = waitUntilStart(queue[1])
	local count = #queue

	if count >= cfg.FFA_MIN then
		local players = popPlayers(math.min(count, cfg.MAX_FFA))
		if #players >= cfg.FFA_MIN and onMatchReady then
			onMatchReady(players)
			return true
		end
		return false
	end

	if count >= 2 and oldestWait >= cfg.PVP_TIMEOUT then
		local players = popPlayers(2)
		if #players == 2 and onMatchReady then
			onMatchReady(players)
			return true
		end
		return false
	end

	if count >= 1 and oldestWait >= cfg.TRAINING_TIMEOUT then
		local players = popPlayers(1)
		if #players == 1 and onMatchReady then
			onMatchReady(players)
			return true
		end
	end

	return false
end

local function ensureTick()
	if tickLoop then
		return
	end
	tickLoop = task.spawn(function()
		while #queue > 0 do
			if tryStartMatch() then
				broadcastUpdate()
			else
				broadcastUpdate()
			end
			task.wait(cfg.TICK_INTERVAL)
			pruneQueue()
		end
		tickLoop = nil
	end)
end

function MatchmakingQueue.init(options)
	remotes = options.remotes
	onMatchReady = options.onMatchReady
	canStartMatch = options.canStartMatch
end

function MatchmakingQueue.enqueue(player)
	if not player or not player.Parent then
		return
	end

	MatchmakingQueue.dequeue(player)
	table.insert(queue, { player = player, joinedAt = os.clock() })
	broadcastUpdate()
	ensureTick()
end

function MatchmakingQueue.dequeue(player)
	for i = #queue, 1, -1 do
		if queue[i].player == player then
			table.remove(queue, i)
			if remotes and player.Parent then
				remotes.MatchQueueUpdate:FireClient(player, { queued = false })
			end
			break
		end
	end
end

function MatchmakingQueue.getCount()
	pruneQueue()
	return #queue
end

function MatchmakingQueue.isQueued(player)
	for _, entry in queue do
		if entry.player == player then
			return true
		end
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.dequeue(player)
end)

return MatchmakingQueue
