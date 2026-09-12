local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerEntry = {}
local fillTimers = {}
local started = false

local function getMode(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function countQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	return #queue
end

local function buildUpdatePayload(modeId, player)
	local mode = getMode(modeId)
	local count = countQueue(modeId)
	local arenaBusy = GameMatchState.isBusy()
	local status = "waiting"
	if arenaBusy then
		status = "pending"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queueCount = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
		position = MatchmakingService.getQueuePosition(player, modeId),
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
		end
	end
end

function MatchmakingService.getQueuePosition(player, modeId)
	local queue = queues[modeId]
	if not queue then
		return nil
	end
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function ensureFillTimer(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 then
		return
	end
	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token
	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStart(modeId, true)
	end)
end

local function removeFromQueue(player, silent)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	if queue then
		for index, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, index)
				break
			end
		end
		if #queue == 0 then
			clearFillTimer(modeId)
		end
	end

	playerEntry[player] = nil

	if not silent and player.Parent then
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			status = "left",
		})
	end

	broadcastQueue(modeId)
end

local function takePlayers(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not queue or #queue == 0 then
		return {}
	end

	local count = math.min(#queue, mode.maxPlayers)
	local picked = {}
	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerEntry[player] = nil
			table.insert(picked, player)
		end
	end

	if #queue == 0 then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
	return picked
end

function MatchmakingService.tryStart(modeId, fromTimeout)
	if GameMatchState.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = getMode(modeId)
	local count = countQueue(modeId)
	if count == 0 then
		return
	end

	local shouldStart = false
	if count >= mode.minPlayers then
		if modeId == "ffa" then
			shouldStart = count >= mode.maxPlayers or fromTimeout == true
		else
			shouldStart = true
		end
	end

	if not shouldStart then
		broadcastQueue(modeId)
		return
	end

	local players = takePlayers(modeId)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
		modeId = "training"
	end

	if playerEntry[player] and playerEntry[player].modeId == modeId then
		broadcastQueue(modeId)
		return
	end

	removeFromQueue(player, true)

	if not queues[modeId] then
		queues[modeId] = {}
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	broadcastQueue(modeId)
	ensureFillTimer(modeId)
	MatchmakingService.tryStart(modeId, false)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player, false)
end

function MatchmakingService.onArenaFree()
	for modeId in MatchmakingConfig.MODES do
		MatchmakingService.tryStart(modeId, true)
	end
end

function MatchmakingService.start(handlers)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	if handlers and handlers.onMatchReady then
		Bindables.MatchReady.Event:Connect(function(payload)
			handlers.onMatchReady(payload)
		end)
	end

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
