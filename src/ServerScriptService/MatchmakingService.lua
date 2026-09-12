local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local arenaBusy = false
local fillTimers = {}
local started = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueIndex(modeId, player)
	for i, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
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

	local index = queueIndex(modeId, player)
	if index then
		table.remove(queues[modeId], index)
	end
	playerQueue[player] = nil

	if fillTimers[modeId] and #queues[modeId] < getModeConfig(modeId).minPlayers then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	local position = queueIndex(modeId, player) or #queue
	local status = arenaBusy and MatchState.QueueStatus.Pending or MatchState.QueueStatus.Searching

	return {
		mode = modeId,
		modeLabel = mode.label,
		position = position,
		total = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function popPlayers(modeId, count)
	local popped = {}
	for _ = 1, count do
		local player = table.remove(queues[modeId], 1)
		if player then
			playerQueue[player] = nil
			table.insert(popped, player)
		end
	end
	return popped
end

local function markStarting(players, modeId)
	for _, player in players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				mode = modeId,
				modeLabel = MatchState.getModeLabel(modeId, MatchmakingConfig),
				status = MatchState.QueueStatus.Starting,
				total = #players,
				needed = getModeConfig(modeId).minPlayers,
				maxPlayers = getModeConfig(modeId).maxPlayers,
				arenaBusy = false,
			})
		end
	end
end

local function tryStartMode(modeId)
	if arenaBusy then
		return
	end

	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if not fillTimers[modeId] then
			local token = { cancelled = false }
			fillTimers[modeId] = token
			task.delay(mode.fillTimeout, function()
				if token.cancelled or arenaBusy then
					return
				end
				fillTimers[modeId] = nil
				local current = queues[modeId]
				if #current < mode.minPlayers then
					return
				end
				local count = math.min(#current, mode.maxPlayers)
				local players = popPlayers(modeId, count)
				if #players >= mode.minPlayers then
					arenaBusy = true
					markStarting(players, modeId)
					MatchReady:Fire({ players = players, mode = modeId })
				end
				broadcastQueue(modeId)
			end)
		end

		if #queue >= mode.maxPlayers then
			fillTimers[modeId] = nil
			local players = popPlayers(modeId, mode.maxPlayers)
			arenaBusy = true
			markStarting(players, modeId)
			MatchReady:Fire({ players = players, mode = modeId })
			broadcastQueue(modeId)
		end
		return
	end

	local players = popPlayers(modeId, mode.maxPlayers)
	arenaBusy = true
	markStarting(players, modeId)
	MatchReady:Fire({ players = players, mode = modeId })
	broadcastQueue(modeId)
end

local function tryStartAll()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		tryStartAll()
	end
	broadcastAllQueues()
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchState.isValidMode(modeId, MatchmakingConfig) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		return false, "already_queued"
	end
	if arenaBusy and getModeConfig(modeId).minPlayers == 1 then
		-- Training can queue while busy but stays pending until arena is free.
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	local modeId = playerQueue[player]
	removeFromQueue(player)
	broadcastQueue(modeId)
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
