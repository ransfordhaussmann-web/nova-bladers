local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables
local MatchReadyBindable

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function initQueues()
	for modeId in pairs(MatchModes.all()) do
		queues[modeId] = {}
	end
end

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function countQueue(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(modeId, player)
	local mode = getMode(modeId)
	local count = countQueue(modeId)
	local pending = MatchStateService.isArenaBusy()
	local status = "waiting"

	if pending then
		status = "pending"
	elseif mode.maxPlayers > 1 and count >= mode.minPlayers then
		if modeId == "ffa" and count < mode.maxPlayers then
			status = "filling"
		else
			status = "ready"
		end
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		pending = pending,
		fillSecondsLeft = fillTimers[modeId],
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	local payload = buildQueuePayload(modeId, player)
	payload.inQueue = true
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	clearFillTimer(modeId)
	sendQueueUpdate(player)
	broadcastQueue(modeId)
end

local function popQueuePlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	clearFillTimer(modeId)
	broadcastQueue(modeId)
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		HubService.enterArena(player)
		sendQueueUpdate(player)
	end

	MatchReadyBindable:Fire(modeId, playerList)
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = getMode(modeId)
	local count = countQueue(modeId)
	if count < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			launchMatch(modeId, popQueuePlayers(modeId, mode.maxPlayers))
		elseif fillTimers[modeId] == nil then
			fillTimers[modeId] = MatchmakingConfig.FFA_FILL_TIMEOUT
			broadcastQueue(modeId)
		elseif fillTimers[modeId] <= 0 then
			launchMatch(modeId, popQueuePlayers(modeId, count))
		end
		return
	end

	if count >= mode.maxPlayers then
		launchMatch(modeId, popQueuePlayers(modeId, mode.maxPlayers))
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = getMode(modeId)
	if not mode then
		return false, "unknown_mode"
	end

	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true, "already_queued"
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueue(modeId)

	if mode.minPlayers == 1 and not MatchStateService.isArenaBusy() then
		tryStartMatch(modeId)
	end

	return true, "joined"
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	for modeId in pairs(MatchModes.all()) do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReadyBindable = Bindables.MatchReady
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)

			for modeId in pairs(MatchModes.all()) do
				if fillTimers[modeId] then
					fillTimers[modeId] -= MatchmakingConfig.QUEUE_TICK
					if fillTimers[modeId] <= 0 then
						fillTimers[modeId] = 0
						tryStartMatch(modeId)
					else
						broadcastQueue(modeId)
					end
				end

				tryStartMatch(modeId)
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
