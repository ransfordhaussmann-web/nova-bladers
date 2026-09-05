local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()
local MatchmakingQueue = Remotes.MatchmakingQueue

local MatchmakingService = {}

local queue = {}
local onMatchReady = nil
local cfg = HubConfig.MATCHMAKING

local function isInQueue(player)
	for _, entry in queue do
		if entry.player == player then
			return true
		end
	end
	return false
end

local function removeFromQueue(player)
	for i, entry in ipairs(queue) do
		if entry.player == player then
			table.remove(queue, i)
			return true
		end
	end
	return false
end

local function getPredictedMode(count)
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

local function getSecondsLeft(count, elapsed)
	if count >= 3 then
		return math.max(0, math.ceil(cfg.FFA_WAIT - elapsed))
	elseif count >= 2 then
		return math.max(0, math.ceil(cfg.PVP_WAIT - elapsed))
	end
	return math.max(0, math.ceil(cfg.SOLO_WAIT - elapsed))
end

local function buildStatusPayload()
	local names = {}
	for _, entry in queue do
		if entry.player.Parent then
			table.insert(names, entry.player.DisplayName)
		end
	end

	local count = #names
	local elapsed = count > 0 and (os.clock() - queue[1].joinedAt) or 0
	local mode = getPredictedMode(count)

	return {
		inQueue = count > 0,
		count = count,
		names = names,
		mode = mode,
		modeLabel = getModeLabel(mode),
		secondsLeft = getSecondsLeft(count, elapsed),
	}
end

local function broadcastQueue()
	local payload = buildStatusPayload()
	for _, entry in queue do
		if entry.player.Parent then
			MatchmakingQueue:FireClient(entry.player, payload)
		end
	end
end

local function pruneQueue()
	for i = #queue, 1, -1 do
		if not queue[i].player.Parent then
			table.remove(queue, i)
		end
	end
end

local function shouldStartMatch()
	pruneQueue()
	local count = #queue
	if count == 0 then
		return false
	end

	local elapsed = os.clock() - queue[1].joinedAt
	if count >= 3 then
		return elapsed >= cfg.FFA_WAIT
	elseif count >= 2 then
		return elapsed >= cfg.PVP_WAIT
	end
	return elapsed >= cfg.SOLO_WAIT
end

local function popMatchPlayers()
	pruneQueue()
	local players = {}
	local limit = cfg.MAX_PLAYERS or 8
	for i = 1, math.min(#queue, limit) do
		table.insert(players, queue[i].player)
	end
	queue = {}
	return players
end

function MatchmakingService.join(player)
	if not player or not player.Parent then
		return
	end
	if isInQueue(player) then
		broadcastQueue()
		return
	end
	table.insert(queue, { player = player, joinedAt = os.clock() })
	broadcastQueue()
end

function MatchmakingService.leave(player)
	if removeFromQueue(player) then
		MatchmakingQueue:FireClient(player, { inQueue = false })
		broadcastQueue()
	end
end

function MatchmakingService.isQueued(player)
	return isInQueue(player)
end

function MatchmakingService.registerMatchReady(callback)
	onMatchReady = callback
end

function MatchmakingService.tick()
	if not shouldStartMatch() then
		if #queue > 0 then
			broadcastQueue()
		end
		return
	end

	local players = popMatchPlayers()
	for _, player in players do
		MatchmakingQueue:FireClient(player, { inQueue = false })
	end

	if #players > 0 and onMatchReady then
		onMatchReady(players)
	end
end

task.spawn(function()
	while true do
		task.wait(cfg.TICK)
		MatchmakingService.tick()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leave(player)
end)

return MatchmakingService
