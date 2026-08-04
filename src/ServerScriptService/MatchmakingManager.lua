--[[
	MatchmakingManager — per-mode queues (Training / 1v1 / FFA) with client status updates.
]]

local Players = game:GetService("Players")

local MatchmakingManager = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local queueJoinedAt = {}
local ffaWaitToken = 0

local remotes
local handlers = {}

local MODE_META = {
	training = {
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
	},
	pvp = {
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
	},
	ffa = {
		label = "FFA",
		minPlayers = 3,
		maxPlayers = 8,
		minPlayersAfterTimeout = 2,
	},
}

local function getConfig()
	return handlers.config or {}
end

local function modeLabel(modeId)
	local meta = MODE_META[modeId]
	return meta and meta.label or modeId
end

local function isValidMode(modeId)
	return MODE_META[modeId] ~= nil
end

local function removeFromQueueList(modeId, player)
	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
			return true
		end
	end
	return false
end

local function buildQueuePayload(modeId)
	local queue = queues[modeId]
	local meta = MODE_META[modeId]
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	local oldestWait = 0
	if #queue > 0 then
		local joinedAt = queueJoinedAt[queue[1]]
		if joinedAt then
			oldestWait = math.floor(os.clock() - joinedAt)
		end
	end

	return {
		mode = modeId,
		modeLabel = modeLabel(modeId),
		playersInQueue = #names,
		requiredPlayers = meta.minPlayers,
		maxPlayers = meta.maxPlayers,
		waitingSeconds = oldestWait,
		playerNames = names,
	}
end

local function broadcastQueueState(modeId)
	if not remotes then
		return
	end
	local payload = buildQueuePayload(modeId)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent and playerQueue[queuedPlayer] == modeId then
			remotes.QueueState:FireClient(queuedPlayer, payload)
		end
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	queueJoinedAt[player] = nil
	removeFromQueueList(modeId, player)
	broadcastQueueState(modeId)
	return modeId
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local matched = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			queueJoinedAt[player] = nil
			table.insert(matched, player)
		end
	end
	broadcastQueueState(modeId)
	return matched
end

local function startMatch(modeId, count)
	local matched = popPlayers(modeId, count)
	if #matched == 0 then
		return
	end
	if handlers.onMatchReady then
		handlers.onMatchReady(matched, modeId)
	end
end

local function tryStartMatch(modeId)
	local queue = queues[modeId]
	local meta = MODE_META[modeId]
	local count = #queue

	if modeId == "training" and count >= meta.minPlayers then
		startMatch(modeId, meta.minPlayers)
	elseif modeId == "pvp" and count >= meta.minPlayers then
		startMatch(modeId, meta.minPlayers)
	elseif modeId == "ffa" and count >= meta.minPlayers then
		startMatch(modeId, math.min(count, meta.maxPlayers))
	end
end

local function scheduleFfaTimeout()
	local config = getConfig()
	local timeout = config.FFA_QUEUE_TIMEOUT or 25
	ffaWaitToken += 1
	local token = ffaWaitToken

	task.delay(timeout, function()
		if token ~= ffaWaitToken then
			return
		end

		local queue = queues.ffa
		local meta = MODE_META.ffa
		local minAfterTimeout = meta.minPlayersAfterTimeout or 2
		if #queue >= minAfterTimeout and #queue < meta.minPlayers then
			startMatch("ffa", math.min(#queue, meta.maxPlayers))
		end
	end)
end

function MatchmakingManager.init(options)
	remotes = options.remotes
	handlers = options

	remotes.JoinQueue.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingManager.join(player, modeId)
	end)

	remotes.LeaveQueue.OnServerEvent:Connect(function(player)
		MatchmakingManager.leave(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingManager.leave(player)
	end)
end

function MatchmakingManager.join(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if handlers.isMatchActive and handlers.isMatchActive() then
		return false
	end
	if handlers.getPhase and handlers.getPhase(player) == "arena" then
		return false
	end

	local previousMode = clearPlayerFromQueues(player)
	if previousMode and previousMode ~= modeId and handlers.onPlayerDequeued then
		handlers.onPlayerDequeued(player, previousMode)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	queueJoinedAt[player] = os.clock()

	if modeId == "ffa" and #queues.ffa == 1 then
		scheduleFfaTimeout()
	end

	if handlers.onPlayerQueued then
		handlers.onPlayerQueued(player, modeId, buildQueuePayload(modeId))
	end
	broadcastQueueState(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingManager.leave(player)
	local modeId = clearPlayerFromQueues(player)
	if modeId and handlers.onPlayerDequeued then
		handlers.onPlayerDequeued(player, modeId)
	end
	return modeId ~= nil
end

function MatchmakingManager.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingManager.isQueued(player)
	return playerQueue[player] ~= nil
end

return MatchmakingManager
