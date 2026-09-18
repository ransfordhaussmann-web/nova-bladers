local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

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
local handlers = {}

local function getQueue(modeId)
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

	if modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		fillTimers.ffa = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local pending = MatchStateService.isArenaBusy()
	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
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
	return picked
end

local function startMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	local playerCount = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		for i = #players, 1, -1 do
			local player = players[i]
			table.insert(queue, 1, player)
			playerQueue[player] = modeId
		end
		return false
	end

	fillTimers[modeId] = nil
	MatchStateService.setArenaBusy(true)

	if handlers.onMatchReady then
		handlers.onMatchReady(players, modeId)
	else
		MatchReady:Fire(players, modeId)
	end

	broadcastAllQueues()
	return true
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			startMatch(modeId)
			return
		end

		if not fillTimers.ffa then
			fillTimers.ffa = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
		elseif os.clock() >= fillTimers.ffa then
			startMatch(modeId)
		end
		return
	end

	startMatch(modeId)
end

local function tryStartAllQueues()
	for modeId in queues do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		modeId = handlers.getQuickMatchMode and handlers.getQuickMatchMode() or "training"
	end

	if playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue >= MatchModes.get(modeId).maxPlayers then
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			modeLabel = MatchModes.get(modeId).label,
			count = #queue,
			minPlayers = MatchModes.get(modeId).minPlayers,
			maxPlayers = MatchModes.get(modeId).maxPlayers,
			pending = MatchStateService.isArenaBusy(),
			inQueue = false,
			full = true,
		})
		return
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueue(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)
end

function MatchmakingService.onArenaFreed()
	fillTimers.ffa = nil
	broadcastAllQueues()
	tryStartAllQueues()
end

function MatchmakingService.init(newHandlers)
	handlers = newHandlers or {}

	MatchStateService.onArenaFreed(function()
		MatchmakingService.onArenaFreed()
	end)

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
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for modeId in queues do
				if fillTimers[modeId] and os.clock() >= fillTimers[modeId] then
					tryStartMode(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
