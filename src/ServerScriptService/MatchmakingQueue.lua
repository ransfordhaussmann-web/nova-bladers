local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local StartMatchBindable = Bindables:FindFirstChild("StartMatch")

local MatchmakingQueue = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local heartbeat = nil

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.mode]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
end

local function buildUpdatePayload(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local modeId = entry.mode
	local count = getQueueCount(modeId)
	local minPlayers = MatchmakingConfig.MIN_PLAYERS[modeId]
	local waited = math.floor(os.clock() - entry.joinedAt)

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = MatchmakingConfig.MODE_LABELS[modeId],
		players = count,
		needed = minPlayers,
		waited = waited,
		maxWait = MatchmakingConfig.MAX_WAIT,
	}
end

local function broadcastQueueUpdates()
	for player, _ in playerEntry do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
		end
	end
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
	end
end

local function canStartMode(modeId)
	local queue = queues[modeId]
	local count = #queue
	if count == 0 then
		return false
	end

	local minPlayers = MatchmakingConfig.MIN_PLAYERS[modeId]
	local oldestEntry = playerEntry[queue[1]]
	local waited = oldestEntry and (os.clock() - oldestEntry.joinedAt) or 0

	if modeId == "training" then
		return count >= 1 and waited >= MatchmakingConfig.SOLO_START_DELAY
	end

	if count >= minPlayers then
		return true
	end

	if modeId == "ffa" and count >= 2 and waited >= MatchmakingConfig.MAX_WAIT then
		return true
	end

	return waited >= MatchmakingConfig.MAX_WAIT and count >= 1
end

local function popPlayersForMatch(modeId)
	local queue = queues[modeId]
	local count = #queue
	if count == 0 then
		return nil
	end

	local take = MatchmakingConfig.MIN_PLAYERS[modeId]
	if modeId == "ffa" then
		take = count
	elseif modeId == "training" then
		take = 1
	else
		take = math.min(2, count)
	end

	if modeId == "ffa" and count < MatchmakingConfig.MIN_PLAYERS.ffa then
		take = count
	end

	local matched = {}
	for _ = 1, take do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(matched, player)
			playerEntry[player] = nil
		end
	end

	return matched
end

local function startMatch(players)
	if #players == 0 then
		return
	end

	for _, player in players do
		HubService.enterArena(player)
	end

	if StartMatchBindable then
		StartMatchBindable:Fire(players)
	end

	broadcastQueueUpdates()
end

local function tryStartMatches()
	for _, modeId in { "ffa", "pvp", "training" } do
		while canStartMode(modeId) do
			local players = popPlayersForMatch(modeId)
			if not players or #players == 0 then
				break
			end
			startMatch(players)
		end
	end
end

local lastTick = 0

local function ensureHeartbeat()
	if heartbeat then
		return
	end
	heartbeat = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTick < MatchmakingConfig.TICK_INTERVAL then
			return
		end
		lastTick = now
		tryStartMatches()
		for player, _ in playerEntry do
			if player.Parent then
				sendQueueUpdate(player)
			end
		end
	end)
end

local function stopHeartbeatIfEmpty()
	if heartbeat and next(playerEntry) == nil then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

function MatchmakingQueue.join(player, modeId)
	if not queues[modeId] then
		return false
	end
	if playerEntry[player] then
		MatchmakingQueue.leave(player)
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		mode = modeId,
		joinedAt = os.clock(),
	}

	HubService.enterQueue(player, modeId)
	sendQueueUpdate(player)
	ensureHeartbeat()
	tryStartMatches()
	return true
end

function MatchmakingQueue.joinAuto(player)
	local count = #Players:GetPlayers()
	if count >= 3 then
		return MatchmakingQueue.join(player, "ffa")
	elseif count == 2 then
		return MatchmakingQueue.join(player, "pvp")
	end
	return MatchmakingQueue.join(player, "training")
end

function MatchmakingQueue.leave(player)
	if not playerEntry[player] then
		return
	end

	removeFromQueue(player)
	HubService.enterHub(player)
	sendQueueUpdate(player)
	stopHeartbeatIfEmpty()
end

function MatchmakingQueue.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingQueue.onPlayerRemoving(player)
	removeFromQueue(player)
	stopHeartbeatIfEmpty()
end

return MatchmakingQueue
