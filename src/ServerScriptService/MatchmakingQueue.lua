--[[
	MatchmakingQueue — forms Training / PvP / FFA matches from hub players.
]]

local Players = game:GetService("Players")

local MatchmakingQueue = {}

local CONFIG = {
	TICK = 0.5,
	SOLO_TRAINING_AFTER = 5,
	PVP_MAX_WAIT = 8,
	FFA_MIN_PLAYERS = 3,
	FFA_MAX_PLAYERS = 6,
	FFA_START_DELAY = 4,
}

local queue = {}
local joinedAt = {}
local thirdPlayerAt = nil
local onMatchReady = nil
local onQueueChanged = nil

local function isInQueue(player)
	for _, queued in queue do
		if queued == player then
			return true
		end
	end
	return false
end

local function pruneQueue()
	local alive = {}
	for _, player in queue do
		if player.Parent then
			table.insert(alive, player)
		else
			joinedAt[player] = nil
		end
	end
	queue = alive
	if #queue < CONFIG.FFA_MIN_PLAYERS then
		thirdPlayerAt = nil
	end
end

local function getProjectedMode(count)
	if count >= CONFIG.FFA_MIN_PLAYERS then
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

local function buildStatus(player)
	pruneQueue()
	local count = #queue
	local position = 0
	for index, queued in queue do
		if queued == player then
			position = index
			break
		end
	end

	if position == 0 then
		return {
			inQueue = false,
			queueSize = count,
			projectedMode = getProjectedMode(count),
		}
	end

	local now = os.clock()
	local waitSeconds = math.floor(now - (joinedAt[player] or now))
	local projectedMode = getProjectedMode(count)
	local modeLabel = getModeLabel(projectedMode)

	local statusText
	if projectedMode == "ffa" then
		statusText = string.format("Warteschlange: %d Spieler (%s)", count, modeLabel)
	elseif projectedMode == "pvp" then
		statusText = string.format("Warteschlange: %d/2 (%s)", count, modeLabel)
	else
		statusText = string.format("Solo-Training in %ds", math.max(0, CONFIG.SOLO_TRAINING_AFTER - waitSeconds))
	end

	return {
		inQueue = true,
		position = position,
		queueSize = count,
		projectedMode = projectedMode,
		modeLabel = modeLabel,
		waitSeconds = waitSeconds,
		statusText = statusText,
	}
end

local function broadcastQueueUpdate()
	if not onQueueChanged then
		return
	end
	pruneQueue()
	for _, player in queue do
		onQueueChanged(player, buildStatus(player))
	end
end

local function popFront(count)
	local players = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player then
			joinedAt[player] = nil
			table.insert(players, player)
		end
	end
	if #queue < CONFIG.FFA_MIN_PLAYERS then
		thirdPlayerAt = nil
	end
	broadcastQueueUpdate()
	return players
end

local function tryFormMatch()
	pruneQueue()
	local count = #queue
	if count == 0 then
		return
	end

	local now = os.clock()
	local firstWait = now - (joinedAt[queue[1]] or now)

	if count >= CONFIG.FFA_MIN_PLAYERS then
		local waitSinceThird = thirdPlayerAt and (now - thirdPlayerAt) or 0
		if count >= CONFIG.FFA_MAX_PLAYERS or waitSinceThird >= CONFIG.FFA_START_DELAY then
			local players = popFront(math.min(count, CONFIG.FFA_MAX_PLAYERS))
			if #players > 0 and onMatchReady then
				onMatchReady(players)
			end
		end
	elseif count == 2 then
		if firstWait >= CONFIG.PVP_MAX_WAIT then
			local players = popFront(2)
			if #players > 0 and onMatchReady then
				onMatchReady(players)
			end
		end
	elseif count == 1 then
		if firstWait >= CONFIG.SOLO_TRAINING_AFTER then
			local players = popFront(1)
			if #players > 0 and onMatchReady then
				onMatchReady(players)
			end
		end
	end
end

function MatchmakingQueue.init(callbacks)
	onMatchReady = callbacks.onMatchReady
	onQueueChanged = callbacks.onQueueChanged

	task.spawn(function()
		while true do
			task.wait(CONFIG.TICK)
			tryFormMatch()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingQueue.leave(player)
	end)
end

function MatchmakingQueue.join(player)
	if not player or not player.Parent or isInQueue(player) then
		return false
	end

	table.insert(queue, player)
	joinedAt[player] = os.clock()
	if #queue == CONFIG.FFA_MIN_PLAYERS then
		thirdPlayerAt = os.clock()
	end
	broadcastQueueUpdate()
	return true
end

function MatchmakingQueue.leave(player)
	if not isInQueue(player) then
		return false
	end

	for index, queued in queue do
		if queued == player then
			table.remove(queue, index)
			break
		end
	end
	joinedAt[player] = nil
	if #queue < CONFIG.FFA_MIN_PLAYERS then
		thirdPlayerAt = nil
	end
	broadcastQueueUpdate()
	return true
end

function MatchmakingQueue.getStatus(player)
	return buildStatus(player)
end

function MatchmakingQueue.isQueued(player)
	return isInQueue(player)
end

return MatchmakingQueue
