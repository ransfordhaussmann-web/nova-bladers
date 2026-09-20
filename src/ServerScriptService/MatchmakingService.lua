--[[
	MatchmakingService — Queue pro Modus, FFA-Fill-Timer, MatchReady-Auslösung.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}

local Remotes
local MatchReady
local MatchEnded

local function initQueues()
	for modeId in MatchModes do
		queues[modeId] = {}
	end
end

local function getSecondsLeft(modeId)
	local timer = fillTimers[modeId]
	if not timer then
		return nil
	end
	return math.max(0, math.ceil(timer.endsAt - os.clock()))
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes[modeId]
	local queue = queues[modeId]
	local count = #queue
	local status = "waiting"

	if MatchStateService.isBusy() and count >= mode.minPlayers then
		status = "pending"
	end

	return {
		inQueue = true,
		modeId = modeId,
		label = mode.label,
		count = count,
		min = mode.minPlayers,
		max = mode.maxPlayers,
		status = status,
		secondsLeft = getSecondsLeft(modeId),
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastModeQueue(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendQueueUpdate(queuedPlayer)
	end
end

local function cancelFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end
	playerQueue[player] = nil

	local mode = MatchModes[modeId]
	if #queue < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	if not silent then
		broadcastModeQueue(modeId)
		sendQueueUpdate(player)
	end
end

local function collectPlayers(modeId, count)
	local players = {}
	for index = 1, count do
		table.insert(players, queues[modeId][index])
	end
	return players
end

local function launchMatch(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player, true)
		HubService.leaveHubForArena(player)
	end

	cancelFillTimer(modeId)
	MatchStateService.setBusy(true)
	MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes[modeId]
	local queue = queues[modeId]
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		broadcastModeQueue(modeId)
		return
	end

	if mode.fillTimeout and count < mode.maxPlayers then
		local timer = fillTimers[modeId]
		if not timer then
			local token = {}
			fillTimers[modeId] = {
				token = token,
				endsAt = os.clock() + mode.fillTimeout,
			}

			task.spawn(function()
				while fillTimers[modeId] and fillTimers[modeId].token == token do
					local currentCount = #queues[modeId]
					if currentCount < mode.minPlayers or MatchStateService.isBusy() then
						return
					end

					if currentCount >= mode.maxPlayers then
						break
					end

					for _, queuedPlayer in queues[modeId] do
						local payload = buildQueuePayload(queuedPlayer)
						payload.secondsLeft = getSecondsLeft(modeId)
						Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
					end

					if os.clock() >= fillTimers[modeId].endsAt then
						break
					end

					task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
				end

				local activeTimer = fillTimers[modeId]
				if not activeTimer or activeTimer.token ~= token then
					return
				end

				cancelFillTimer(modeId)

				if MatchStateService.isBusy() then
					broadcastModeQueue(modeId)
					return
				end

				local readyCount = #queues[modeId]
				if readyCount >= mode.minPlayers then
					local playerCount = math.min(readyCount, mode.maxPlayers)
					launchMatch(modeId, collectPlayers(modeId, playerCount))
				end
			end)
			return
		end

		if count >= mode.maxPlayers then
			cancelFillTimer(modeId)
			launchMatch(modeId, collectPlayers(modeId, mode.maxPlayers))
		end
		return
	end

	local playerCount = math.min(count, mode.maxPlayers)
	launchMatch(modeId, collectPlayers(modeId, playerCount))
end

local function addToQueue(player, modeId)
	if not MatchModes[modeId] then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player, true)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	broadcastModeQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	for modeId in MatchModes do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	addToQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.init(remotes, bindables)
	Remotes = remotes
	MatchReady = bindables.MatchReady
	MatchEnded = bindables.MatchEnded

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not MatchModes[modeId] then
			return
		end
		addToQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		removeFromQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)
end

return MatchmakingService
