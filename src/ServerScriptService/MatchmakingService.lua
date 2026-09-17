local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function getQueuePlayers(modeId)
	local list = {}
	for _, player in queues[modeId] or {} do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, queued in queue do
			if queued == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local count = getQueueSize(modeId)
	local arenaBusy = MatchStateService.isArenaBusy()
	local pending = arenaBusy and count >= mode.minPlayers

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdate()
	for player, _ in playerQueue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function fireMatchReady(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
	end
	broadcastQueueUpdate()
	MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueuePlayers(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate()
		return
	end

	if mode.fillTimeout > 0 and count < mode.maxPlayers then
		if fillTimers[modeId] then
			return
		end

		local token = { cancelled = false }
		fillTimers[modeId] = token
		broadcastQueueUpdate()

		task.delay(mode.fillTimeout, function()
			if token.cancelled or fillTimers[modeId] ~= token then
				return
			end
			fillTimers[modeId] = nil

			local ready = getQueuePlayers(modeId)
			if #ready >= mode.minPlayers and not MatchStateService.isArenaBusy() then
				local matchPlayers = {}
				for i = 1, math.min(#ready, mode.maxPlayers) do
					table.insert(matchPlayers, ready[i])
				end
				fireMatchReady(modeId, matchPlayers)
			else
				broadcastQueueUpdate()
			end
		end)
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(count, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end
	fireMatchReady(modeId, matchPlayers)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate()
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.getRecommendedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedMode()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		for _, mode in MatchModes.all() do
			tryStartMatch(mode.id)
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
