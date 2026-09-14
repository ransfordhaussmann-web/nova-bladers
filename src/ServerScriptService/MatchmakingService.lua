--[[
	MatchmakingService — Queue pro Modus, MatchReady wenn genug Spieler.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function queueIndex(modeId, player)
	local queue = getQueue(modeId)
	for i, p in queue do
		if p == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	local idx = queueIndex(modeId, player)
	if idx then
		table.remove(queue, idx)
	end
	playerQueue[player] = nil

	if fillTimers[modeId] then
		local mode = MatchModes.get(modeId)
		if mode and #queue < mode.minPlayers then
			fillTimers[modeId] = nil
		end
	end
end

local function getStatus(modeId)
	if MatchStateService.isBusy() then
		return "pending"
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if modeId == "training" and count >= 1 then
		return "ready"
	elseif modeId == "pvp" and count >= mode.minPlayers then
		return "ready"
	elseif modeId == "ffa" then
		if count >= mode.maxPlayers then
			return "ready"
		elseif count >= mode.minPlayers and fillTimers[modeId] then
			return "filling"
		end
	end

	return "waiting"
end

local function buildUpdatePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, p in queue do
		if p.Parent then
			table.insert(names, p.DisplayName)
		end
	end

	local payload = {
		modeId = modeId,
		modeLabel = mode.label,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		players = names,
		status = getStatus(modeId),
		inQueue = true,
	}

	if modeId == "ffa" and fillTimers[modeId] and mode.fillTimeout > 0 then
		local elapsed = os.clock() - fillTimers[modeId]
		payload.fillRemaining = math.max(0, math.ceil(mode.fillTimeout - elapsed))
	end

	return payload
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
		end
	end
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	fillTimers[modeId] = nil
	return picked
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local count = #queue

	if modeId == "training" then
		if count < 1 then
			return
		end
	elseif modeId == "pvp" then
		if count < mode.minPlayers then
			return
		end
	elseif modeId == "ffa" then
		if count >= mode.maxPlayers then
			-- start immediately at cap
		elseif count >= mode.minPlayers and fillTimers[modeId] then
			local elapsed = os.clock() - fillTimers[modeId]
			if elapsed < mode.fillTimeout then
				return
			end
		else
			return
		end
	end

	local playerCount = math.min(count, mode.maxPlayers)
	local players = popPlayers(modeId, playerCount)
	if #players == 0 then
		return
	end

	task.delay(MatchmakingConfig.START_DELAY, function()
		MatchReady:Fire(players, modeId)
	end)

	for _, modeKey in { "training", "pvp", "ffa" } do
		broadcastQueueUpdate(modeKey)
	end
end

local function maybeStartFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	local queue = getQueue(modeId)
	if #queue >= mode.minPlayers and not fillTimers[modeId] then
		fillTimers[modeId] = os.clock()
		task.delay(mode.fillTimeout, function()
			tryStartMatch(modeId)
		end)
	end
end

local function tryAllQueues()
	for _, modeId in { "training", "pvp", "ffa" } do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "unknown_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(modeId)

	if modeId == "ffa" then
		maybeStartFillTimer(modeId)
	end

	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	tryAllQueues()
end

function MatchmakingService.start()
	started = true

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onChange(function(busy)
		if not busy then
			MatchmakingService.onArenaFreed()
		end
		for _, modeId in { "training", "pvp", "ffa" } do
			broadcastQueueUpdate(modeId)
		end
	end)

	task.spawn(function()
		while started do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			if not MatchStateService.isBusy() then
				tryAllQueues()
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
