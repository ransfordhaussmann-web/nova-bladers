--[[
	Matchmaking queue — gathers players before Bey selection / match start.
	Solo wait → Training; 2 players → 1v1 PvP; 3+ → FFA (up to QUEUE_MAX_PLAYERS).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeyConfig = require(ReplicatedStorage.NovaBladers.BeyConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local queue = {}
local gatherToken = 0
local flushing = false

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

local function findInQueue(player)
	for i, p in ipairs(queue) do
		if p == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local idx = findInQueue(player)
	if idx then
		table.remove(queue, idx)
		return true
	end
	return false
end

local function buildUpdatePayload()
	local count = #queue
	local mode = getModeForCount(count)
	return {
		inQueue = true,
		count = count,
		mode = mode,
		modeLabel = getModeLabel(mode),
		minPlayers = mode == "ffa" and 3 or (mode == "pvp" and 2 or 1),
	}
end

local function broadcastUpdate()
	local payload = buildUpdatePayload()
	for _, player in ipairs(queue) do
		if player.Parent then
			Remotes.MatchmakingUpdate:FireClient(player, payload)
		end
	end
end

local function flushQueue()
	if flushing or #queue == 0 then
		return
	end

	flushing = true
	gatherToken += 1

	local count = #queue
	local take = 1
	if count >= 3 then
		take = math.min(count, BeyConfig.QUEUE_MAX_PLAYERS or 8)
	elseif count >= 2 then
		take = 2
	end

	local batch = {}
	for _ = 1, take do
		table.insert(batch, queue[1])
		table.remove(queue, 1)
	end

	Bindables.BeginMatch:Fire(batch)
	broadcastUpdate()

	flushing = false

	if #queue > 0 then
		scheduleGather()
	end
end

local function scheduleGather()
	gatherToken += 1
	local token = gatherToken
	local count = #queue

	local delay
	if count >= 3 then
		delay = BeyConfig.QUEUE_GATHER_SECONDS
	elseif count >= 2 then
		delay = BeyConfig.QUEUE_GATHER_SECONDS
	else
		delay = BeyConfig.QUEUE_SOLO_WAIT_SECONDS
	end

	task.delay(delay, function()
		if token ~= gatherToken or #queue == 0 then
			return
		end
		flushQueue()
	end)
end

local MatchmakingManager = {}

function MatchmakingManager.isQueued(player)
	return findInQueue(player) ~= nil
end

function MatchmakingManager.join(player)
	if findInQueue(player) then
		return
	end

	table.insert(queue, player)
	broadcastUpdate()
	scheduleGather()
end

function MatchmakingManager.leave(player)
	if not removeFromQueue(player) then
		return
	end

	gatherToken += 1

	if player.Parent then
		Remotes.MatchmakingUpdate:FireClient(player, { inQueue = false })
	end

	if #queue > 0 then
		scheduleGather()
	else
		broadcastUpdate()
	end
end

function MatchmakingManager.init()
	Remotes.MatchmakingLeave.OnServerEvent:Connect(function(player)
		MatchmakingManager.leave(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingManager.leave(player)
	end)
end

return MatchmakingManager
