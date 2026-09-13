local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoinRemote = Remotes.QueueJoin
local QueueLeaveRemote = Remotes.QueueLeave
local QueueUpdateRemote = Remotes.QueueUpdate
local MatchReadyBindable = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local fillTokens = {}

for _, mode in MatchModes.all() do
	queues[mode.id] = {}
end

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function isPlayerValid(player)
	return player and player.Parent and HubService.getPhase(player) == "hub"
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local cleaned = {}
	for _, player in queue do
		if isPlayerValid(player) then
			table.insert(cleaned, player)
		else
			playerQueue[player] = nil
		end
	end
	queues[modeId] = cleaned
end

local function buildQueuePayload(modeId, player)
	local mode = getMode(modeId)
	pruneQueue(modeId)
	local queue = queues[modeId]
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local pending = GameMatchState.isArenaBusy()
	local fillRemaining = nil
	if mode.fillTimeout and fillTimers[modeId] then
		fillRemaining = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		fillRemaining = fillRemaining,
		status = pending and "pending" or "waiting",
	}
end

local function broadcastQueue(modeId)
	pruneQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			QueueUpdateRemote:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if #queue < getMode(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

local function popPlayers(modeId, count)
	pruneQueue(modeId)
	local selected = {}
	local queue = queues[modeId]
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player then
			playerQueue[player] = nil
			table.insert(selected, player)
		end
	end
	clearFillTimer(modeId)
	return selected
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end
	if GameMatchState.isArenaBusy() then
		return
	end

	GameMatchState.setArenaBusy(true)
	for _, player in playerList do
		HubService.leaveHubForArena(player)
	end
	MatchReadyBindable:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMatch(modeId)
	if GameMatchState.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = getMode(modeId)
	pruneQueue(modeId)
	local queue = queues[modeId]

	if #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout then
		local timer = fillTimers[modeId]
		if timer then
			if #queue >= mode.maxPlayers or os.clock() >= timer.endsAt then
				clearFillTimer(modeId)
			else
				broadcastQueue(modeId)
				return
			end
		else
			fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
			local token = fillTokens[modeId]
			local endsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
			fillTimers[modeId] = { endsAt = endsAt, token = token }
			broadcastQueue(modeId)

			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if fillTimers[modeId] and fillTimers[modeId].token ~= token then
					return
				end
				clearFillTimer(modeId)
				tryStartMatch(modeId)
			end)
			return
		end
	end

	local count = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, count)
	launchMatch(modeId, players)
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if not isPlayerValid(player) then
		return false, "not_in_hub"
	end
	if playerQueue[player] == modeId then
		return true
	end

	removeFromQueue(player)

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.join(player, modeId)
	return joinQueue(player, modeId)
end

function MatchmakingService.leave(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start()
	Bindables.ArenaFree.Event:Connect(function()
		GameMatchState.setArenaBusy(false)
	end)

	GameMatchState.onArenaFree(function()
		for modeId in queues do
			tryStartMatch(modeId)
		end
	end)

	QueueJoinRemote.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		joinQueue(player, modeId)
	end)

	QueueLeaveRemote.OnServerEvent:Connect(function(player)
		removeFromQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
