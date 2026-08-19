--[[
	MatchmakingQueue — groups arena-ready players into Training / 1v1 / FFA matches.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingQueue = {}

local CONFIG = {
	TRAINING_SOLO_WAIT = 3,
	PVP_PAIR_WAIT = 4,
	FFA_MIN_PLAYERS = 3,
	MAX_WAIT = 40,
	TICK_INTERVAL = 0.5,
	MAX_FFA_PLAYERS = 8,
}

local Remotes, Bindables = RemotesSetup.ensure()
local queue = {}
local canStartMatch = nil
local tickRunning = false

local function getModeFromCount(count)
	if count >= CONFIG.FFA_MIN_PLAYERS then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function modeLabel(mode)
	if mode == "ffa" then
		return "FFA"
	elseif mode == "pvp" then
		return "1v1 PvP"
	end
	return "Training"
end

local function findEntry(player)
	for i, entry in queue do
		if entry.player == player then
			return entry, i
		end
	end
	return nil
end

local function buildUpdate(player, entry)
	local total = #queue
	local position = 0
	for i, e in queue do
		if e.player == player then
			position = i
			break
		end
	end

	local mode = getModeFromCount(total)
	local waitSeconds = entry and (os.clock() - entry.joinedAt) or 0
	local eta
	if mode == "training" then
		eta = math.max(0, CONFIG.TRAINING_SOLO_WAIT - waitSeconds)
	elseif mode == "pvp" then
		eta = total >= 2 and 0 or math.max(0, CONFIG.PVP_PAIR_WAIT - waitSeconds)
	elseif mode == "ffa" then
		eta = total >= CONFIG.FFA_MIN_PLAYERS and 0 or math.max(0, CONFIG.MAX_WAIT - waitSeconds)
	end

	return {
		inQueue = entry ~= nil,
		position = position,
		total = total,
		mode = mode,
		modeLabel = modeLabel(mode),
		eta = math.ceil(eta or 0),
		needed = mode == "ffa" and math.max(0, CONFIG.FFA_MIN_PLAYERS - total) or (mode == "pvp" and math.max(0, 2 - total) or 0),
	}
end

local function broadcastQueue()
	for _, entry in queue do
		local player = entry.player
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdate(player, entry))
		end
	end
end

local function clearPlayerQueueState(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

function MatchmakingQueue.setCanStartMatch(fn)
	canStartMatch = fn
end

function MatchmakingQueue.leave(player)
	local _, idx = findEntry(player)
	if not idx then
		return
	end
	table.remove(queue, idx)
	clearPlayerQueueState(player)
	broadcastQueue()
end

function MatchmakingQueue.join(player)
	if findEntry(player) then
		broadcastQueue()
		return
	end

	table.insert(queue, {
		player = player,
		joinedAt = os.clock(),
	})

	broadcastQueue()
	MatchmakingQueue.ensureTick()
end

local function popPlayers(count)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local entry = table.remove(queue, 1)
		if entry and entry.player.Parent then
			table.insert(picked, entry.player)
		end
	end
	return picked
end

local function tryStart()
	if not canStartMatch or not canStartMatch() then
		return
	end

	if #queue == 0 then
		return
	end

	local now = os.clock()
	local oldestWait = now - queue[1].joinedAt

	-- FFA: enough players or max wait reached with 3+
	if #queue >= CONFIG.FFA_MIN_PLAYERS then
		local count = math.min(#queue, CONFIG.MAX_FFA_PLAYERS)
		local players = popPlayers(count)
		if #players >= CONFIG.FFA_MIN_PLAYERS then
			Bindables.StartMatch:Fire(players)
			broadcastQueue()
		end
		return
	end

	if oldestWait >= CONFIG.MAX_WAIT and #queue >= 2 then
		local mode = getModeFromCount(#queue)
		local count = mode == "pvp" and 2 or #queue
		local players = popPlayers(count)
		if #players >= 2 then
			Bindables.StartMatch:Fire(players)
			broadcastQueue()
		end
		return
	end

	-- PvP: two players waited long enough
	if #queue >= 2 and oldestWait >= CONFIG.PVP_PAIR_WAIT then
		local players = popPlayers(2)
		if #players == 2 then
			Bindables.StartMatch:Fire(players)
			broadcastQueue()
		end
		return
	end

	-- Training: solo after short wait
	if #queue == 1 and oldestWait >= CONFIG.TRAINING_SOLO_WAIT then
		local players = popPlayers(1)
		if #players == 1 then
			Bindables.StartMatch:Fire(players)
			broadcastQueue()
		end
	end
end

function MatchmakingQueue.ensureTick()
	if tickRunning then
		return
	end
	tickRunning = true

	task.spawn(function()
		while #queue > 0 do
			tryStart()
			task.wait(CONFIG.TICK_INTERVAL)
		end
		tickRunning = false
	end)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.leave(player)
end)

return MatchmakingQueue
