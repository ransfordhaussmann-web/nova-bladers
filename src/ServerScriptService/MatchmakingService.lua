local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function getQueueStatus(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif #queue >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		label = mode.label,
		position = position,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, getQueueStatus(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	for _, player in playerList do
		HubService.leaveHubForArena(player)
	end

	MatchStateService.setBusy(true)
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})

	broadcastAllQueues()
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		broadcastQueue(modeId)
		return
	end

	if mode.fillTimeout > 0 and #queue < mode.maxPlayers then
		if not fillTimers[modeId] then
			fillTimers[modeId] = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				if MatchStateService.isBusy() then
					broadcastQueue(modeId)
					return
				end
				local current = getQueue(modeId)
				if #current >= mode.minPlayers then
					local count = math.min(#current, mode.maxPlayers)
					launchMatch(modeId, takePlayersFromQueue(modeId, count))
				end
			end)
		end
		broadcastQueue(modeId)
		return
	end

	local count = math.min(#queue, mode.maxPlayers)
	launchMatch(modeId, takePlayersFromQueue(modeId, count))
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	tryStartMatch(modeId)
	broadcastQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	broadcastQueue(modeId)
end

function MatchmakingService.onArenaFree()
	MatchStateService.setBusy(false)
	broadcastAllQueues()

	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerQueue[player]
		if modeId then
			removeFromQueue(player)
			broadcastQueue(modeId)
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
