--[[
	MatchmakingQueue — wartende Spieler sammeln, Modus wählen, Match starten.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local MatchmakingQueue = {}

local queue = {}
local queueByPlayer = {}
local onMatchReady = nil
local remotes = nil
local hubCallbacks = nil

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

local function buildStatus(player)
	local entry = queueByPlayer[player]
	if not entry then
		return { inQueue = false }
	end

	local total = #queue
	local mode = getModeForCount(total)
	local oldestWait = os.clock() - queue[1].joinedAt
	local needed = 0
	if mode == "training" then
		needed = math.max(0, 1 - total)
	elseif mode == "pvp" then
		needed = math.max(0, 2 - total)
	else
		needed = math.max(0, 3 - total)
	end

	local position = 1
	for i, e in queue do
		if e.player == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		position = position,
		total = total,
		mode = mode,
		modeLabel = getModeLabel(mode),
		waitSeconds = math.floor(oldestWait),
		needed = needed,
	}
end

local function broadcastStatus()
	if not remotes then
		return
	end
	for _, entry in queue do
		local player = entry.player
		if player.Parent then
			remotes.MatchQueueState:FireClient(player, buildStatus(player))
		end
	end
end

local function removeFromQueue(player)
	local entry = queueByPlayer[player]
	if not entry then
		return
	end
	queueByPlayer[player] = nil
	for i, e in queue do
		if e.player == player then
			table.remove(queue, i)
			break
		end
	end
	if player.Parent and remotes then
		remotes.MatchQueueState:FireClient(player, { inQueue = false })
	end
end

local function shouldStartMatch()
	local count = #queue
	if count == 0 then
		return false
	end

	local oldestWait = os.clock() - queue[1].joinedAt
	if count >= 3 then
		return true
	end
	if count >= 2 and oldestWait >= HubConfig.QUEUE_PVP_WAIT then
		return true
	end
	if count >= 1 and oldestWait >= HubConfig.QUEUE_MAX_WAIT then
		return true
	end
	return false
end

local function popMatchPlayers()
	local count = #queue
	local mode = getModeForCount(count)
	local take = count
	if mode == "pvp" then
		take = math.min(2, count)
	elseif mode == "training" then
		take = 1
	else
		take = math.min(HubConfig.QUEUE_MAX_PLAYERS, count)
	end

	local players = {}
	for _ = 1, take do
		local entry = table.remove(queue, 1)
		if entry then
			queueByPlayer[entry.player] = nil
			table.insert(players, entry.player)
		end
	end
	return players, mode
end

local function tryStartMatch()
	if not shouldStartMatch() then
		return
	end

	local players, mode = popMatchPlayers()
	if #players == 0 then
		return
	end

	broadcastStatus()

	if hubCallbacks and hubCallbacks.prepareForMatch then
		hubCallbacks.prepareForMatch(players, mode)
	end

	if onMatchReady then
		onMatchReady(players, mode)
	end
end

function MatchmakingQueue.init(opts)
	remotes = opts.remotes
	hubCallbacks = opts.hubCallbacks
	onMatchReady = opts.onMatchReady

	task.spawn(function()
		while true do
			task.wait(HubConfig.QUEUE_TICK)
			tryStartMatch()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		broadcastStatus()
	end)
end

function MatchmakingQueue.join(player)
	if queueByPlayer[player] then
		remotes.MatchQueueState:FireClient(player, buildStatus(player))
		return false
	end

	table.insert(queue, {
		player = player,
		joinedAt = os.clock(),
	})
	queueByPlayer[player] = queue[#queue]
	broadcastStatus()
	return true
end

function MatchmakingQueue.leave(player)
	if not queueByPlayer[player] then
		return false
	end
	removeFromQueue(player)
	broadcastStatus()
	return true
end

function MatchmakingQueue.isQueued(player)
	return queueByPlayer[player] ~= nil
end

function MatchmakingQueue.remove(player)
	removeFromQueue(player)
end

return MatchmakingQueue
