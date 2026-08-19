--[[
	MatchmakingService — queue players before arena matches.
	Gathers players for a short window, then starts Training / 1v1 / FFA by count.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local GATHER_TIME = 5
local EARLY_START_PVP = 2
local TICK_INTERVAL = 0.25

local queue = {}
local queueByPlayer = {}
local gatherStartedAt = nil
local tickLoop = nil
local onMatchReady = nil

local Remotes

local function getModeFromCount(count)
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

local function buildStatus(forPlayer)
	local entries = {}
	for _, entry in queue do
		if entry.player.Parent then
			table.insert(entries, entry.player.DisplayName)
		end
	end

	local count = #entries
	local mode = getModeFromCount(count)
	local timeLeft = 0

	if gatherStartedAt and count > 0 then
		local elapsed = os.clock() - gatherStartedAt
		timeLeft = math.max(0, math.ceil(GATHER_TIME - elapsed))
	end

	return {
		inQueue = forPlayer and queueByPlayer[forPlayer] ~= nil,
		count = count,
		players = entries,
		mode = mode,
		modeLabel = getModeLabel(mode),
		timeLeft = timeLeft,
	}
end

local function broadcastQueue()
	local status = buildStatus()
	for _, entry in queue do
		local player = entry.player
		if player.Parent then
			local personal = table.clone(status)
			personal.inQueue = true
			Remotes.QueueUpdate:FireClient(player, personal)
		end
	end
end

local function stopTickLoop()
	if tickLoop then
		task.cancel(tickLoop)
		tickLoop = nil
	end
end

local function clearQueue()
	table.clear(queue)
	table.clear(queueByPlayer)
	gatherStartedAt = nil
	stopTickLoop()
end

local function popQueueAndStart()
	if #queue == 0 then
		return
	end

	local players = {}
	for _, entry in queue do
		if entry.player.Parent then
			table.insert(players, entry.player)
		end
	end

	clearQueue()

	if #players > 0 and onMatchReady then
		onMatchReady(players)
	end
end

local function shouldStartMatch()
	local count = #queue
	if count == 0 then
		return false
	end

	local elapsed = gatherStartedAt and (os.clock() - gatherStartedAt) or 0

	if count >= 3 then
		return true
	end
	if count >= 2 and elapsed >= EARLY_START_PVP then
		return true
	end
	if elapsed >= GATHER_TIME then
		return true
	end

	return false
end

local function tick()
	while #queue > 0 do
		if shouldStartMatch() then
			popQueueAndStart()
			return
		end
		broadcastQueue()
		task.wait(TICK_INTERVAL)
	end
	stopTickLoop()
end

local function ensureTickLoop()
	if tickLoop then
		return
	end
	tickLoop = task.spawn(tick)
end

function MatchmakingService.init(callback)
	onMatchReady = callback
	Remotes = RemotesSetup.ensure()
end

function MatchmakingService.join(player)
	if queueByPlayer[player] then
		return
	end

	local entry = { player = player, joinedAt = os.clock() }
	table.insert(queue, entry)
	queueByPlayer[player] = entry

	if not gatherStartedAt then
		gatherStartedAt = os.clock()
	end

	broadcastQueue()
	ensureTickLoop()
end

function MatchmakingService.leave(player)
	local entry = queueByPlayer[player]
	if not entry then
		return
	end

	queueByPlayer[player] = nil
	for i, e in queue do
		if e == entry then
			table.remove(queue, i)
			break
		end
	end

	if #queue == 0 then
		clearQueue()
	else
		broadcastQueue()
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.isQueued(player)
	return queueByPlayer[player] ~= nil
end

function MatchmakingService.getStatus(player)
	return buildStatus(player)
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leave(player)
end

return MatchmakingService
