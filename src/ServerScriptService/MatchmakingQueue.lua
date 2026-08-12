--[[
	MatchmakingQueue — arena queue with visible status and mode-based start rules.
	Training (solo) after SOLO_TIMEOUT; PvP at 2+; FFA at 3+.
]]

local Players = game:GetService("Players")

local MatchmakingQueue = {}

local GATHER_DELAY = 2
local SOLO_TIMEOUT = 12
local MIN_PVP = 2
local MIN_FFA = 3
local TICK_INTERVAL = 0.5

local queue = {}
local queueSet = {}
local joinedAt = {}
local gatherToken = 0
local scheduledToken = nil
local tickThread = nil

local callbacks = {
	canStart = function()
		return true
	end,
	onMatchReady = function(_players) end,
	broadcast = function(_player, _payload) end,
}

local function getValidQueue()
	local valid = {}
	for _, player in queue do
		if player.Parent and queueSet[player] then
			table.insert(valid, player)
		end
	end
	return valid
end

local function modeForCount(count)
	if count >= MIN_FFA then
		return "ffa"
	elseif count >= MIN_PVP then
		return "pvp"
	end
	return "training"
end

local function modeLabelForCount(count)
	if count >= MIN_FFA then
		return "FFA startet"
	elseif count >= MIN_PVP then
		return "1v1 startet"
	end
	return "Training (Solo)"
end

local function secondsUntilStart(valid)
	local count = #valid
	if count >= MIN_PVP then
		return GATHER_DELAY
	end
	if count >= 1 then
		local oldest = os.clock()
		for _, player in valid do
			local joined = joinedAt[player] or os.clock()
			if joined < oldest then
				oldest = joined
			end
		end
		return math.max(0, math.ceil(SOLO_TIMEOUT - (os.clock() - oldest)))
	end
	return nil
end

function MatchmakingQueue.configure(opts)
	if opts.canStart then
		callbacks.canStart = opts.canStart
	end
	if opts.onMatchReady then
		callbacks.onMatchReady = opts.onMatchReady
	end
	if opts.broadcast then
		callbacks.broadcast = opts.broadcast
	end
end

function MatchmakingQueue.getSnapshot(player)
	local valid = getValidQueue()
	local count = #valid
	local position = nil
	for i, queued in valid do
		if queued == player then
			position = i
			break
		end
	end

	return {
		inQueue = position ~= nil,
		position = position,
		total = count,
		mode = modeForCount(count),
		modeLabel = modeLabelForCount(count),
		secondsUntilStart = secondsUntilStart(valid),
		minPlayers = count >= MIN_FFA and MIN_FFA or MIN_PVP,
	}
end

function MatchmakingQueue.broadcastAll()
	for _, player in getValidQueue() do
		callbacks.broadcast(player, MatchmakingQueue.getSnapshot(player))
	end
end

local function pruneInvalid()
	for i = #queue, 1, -1 do
		local player = queue[i]
		if not player.Parent or not queueSet[player] then
			queueSet[player] = nil
			joinedAt[player] = nil
			table.remove(queue, i)
		end
	end
end

local function dequeuePlayers(players)
	local removeSet = {}
	for _, player in players do
		removeSet[player] = true
	end

	for i = #queue, 1, -1 do
		if removeSet[queue[i]] then
			queueSet[queue[i]] = nil
			joinedAt[queue[i]] = nil
			table.remove(queue, i)
		end
	end
end

local function scheduleStart(players, _mode)
	if scheduledToken then
		return
	end

	gatherToken += 1
	scheduledToken = gatherToken
	local token = gatherToken

	task.delay(GATHER_DELAY, function()
		if token ~= scheduledToken then
			return
		end
		scheduledToken = nil

		if not callbacks.canStart() then
			return
		end

		pruneInvalid()
		local ready = {}
		local playerSet = {}
		for _, player in players do
			playerSet[player] = true
		end
		for _, player in queue do
			if playerSet[player] and player.Parent and queueSet[player] then
				table.insert(ready, player)
			end
		end

		if #ready == 0 then
			return
		end

		local mode = modeForCount(#ready)
		if mode == "training" then
			ready = { ready[1] }
		end

		dequeuePlayers(ready)
		MatchmakingQueue.broadcastAll()
		callbacks.onMatchReady(ready)
	end)
end

function MatchmakingQueue.evaluate()
	pruneInvalid()
	if not callbacks.canStart() then
		return
	end

	local valid = getValidQueue()
	local count = #valid
	if count == 0 then
		return
	end

	if count >= MIN_FFA then
		scheduleStart(valid, "ffa")
	elseif count >= MIN_PVP then
		scheduleStart(valid, "pvp")
	else
		local oldest = os.clock()
		for _, player in valid do
			local joined = joinedAt[player] or os.clock()
			if joined < oldest then
				oldest = joined
			end
		end
		if os.clock() - oldest >= SOLO_TIMEOUT then
			scheduleStart({ valid[1] }, "training")
		end
	end
end

local function ensureTick()
	if tickThread then
		return
	end
	tickThread = task.spawn(function()
		while #queue > 0 do
			MatchmakingQueue.evaluate()
			MatchmakingQueue.broadcastAll()
			task.wait(TICK_INTERVAL)
		end
		tickThread = nil
	end)
end

function MatchmakingQueue.join(player)
	if not player or not player.Parent then
		return false
	end
	if queueSet[player] then
		MatchmakingQueue.broadcastAll()
		return true
	end

	table.insert(queue, player)
	queueSet[player] = true
	joinedAt[player] = os.clock()
	MatchmakingQueue.broadcastAll()
	ensureTick()
	MatchmakingQueue.evaluate()
	return true
end

function MatchmakingQueue.leave(player)
	if not queueSet[player] then
		return false
	end

	queueSet[player] = nil
	joinedAt[player] = nil
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	gatherToken += 1
	scheduledToken = nil
	callbacks.broadcast(player, { inQueue = false })
	MatchmakingQueue.broadcastAll()
	return true
end

function MatchmakingQueue.remove(player)
	MatchmakingQueue.leave(player)
end

function MatchmakingQueue.contains(player)
	return queueSet[player] == true
end

function MatchmakingQueue.isEmpty()
	return #getValidQueue() == 0
end

function MatchmakingQueue.cancelPendingStart()
	gatherToken += 1
	scheduledToken = nil
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.remove(player)
end)

return MatchmakingQueue
