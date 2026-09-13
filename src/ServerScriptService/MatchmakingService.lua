local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerMode = {}
local fillTokens = {}
local fillThreads = {}
local hubCallbacks = {}
local started = false

for _, modeId in MatchmakingConfig.MODE_ORDER do
	queues[modeId] = {}
end

local function getQueueList(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function pruneQueue(modeId)
	local cleaned = {}
	for _, player in queues[modeId] do
		if player.Parent and playerMode[player] == modeId then
			table.insert(cleaned, player)
		else
			playerMode[player] = nil
		end
	end
	queues[modeId] = cleaned
end

local function playerNames(list)
	local names = {}
	for _, player in list do
		table.insert(names, player.DisplayName)
	end
	return names
end

local function buildUpdatePayload(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return nil
	end

	pruneQueue(modeId)
	local list = getQueueList(modeId)
	local count = #list
	local needed = math.max(0, mode.minPlayers - count)
	local status = "waiting"

	if count >= mode.minPlayers then
		status = GameMatchState.isArenaBusy() and "pending" or "ready"
	end

	if playerMode[player] ~= modeId then
		return {
			inQueue = false,
			modeId = modeId,
			modeLabel = mode.label,
			count = count,
			needed = needed,
			max = mode.maxPlayers,
			status = status,
			arenaBusy = GameMatchState.isArenaBusy(),
			players = playerNames(list),
		}
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		needed = needed,
		max = mode.maxPlayers,
		status = status,
		arenaBusy = GameMatchState.isArenaBusy(),
		players = playerNames(list),
	}
end

local function broadcastMode(modeId)
	pruneQueue(modeId)
	for _, player in getQueueList(modeId) do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		broadcastMode(modeId)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillThreads[modeId] = nil
end

local function removeFromAllQueues(player)
	local previousMode = playerMode[player]
	playerMode[player] = nil
	if previousMode then
		local list = queues[previousMode]
		for i, queued in list do
			if queued == player then
				table.remove(list, i)
				break
			end
		end
		cancelFillTimer(previousMode)
		broadcastMode(previousMode)
	end
end

local function popMatchPlayers(modeId)
	pruneQueue(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local list = getQueueList(modeId)
	local take = math.min(#list, mode.maxPlayers)
	if take < mode.minPlayers then
		return nil
	end

	local matchPlayers = {}
	for i = 1, take do
		local player = list[1]
		table.remove(list, 1)
		playerMode[player] = nil
		table.insert(matchPlayers, player)
	end

	cancelFillTimer(modeId)
	broadcastMode(modeId)
	return matchPlayers
end

local function launchMatch(modeId, matchPlayers)
	if hubCallbacks.preparePlayers then
		hubCallbacks.preparePlayers(matchPlayers)
	end
	Bindables.MatchReady:Fire(modeId, matchPlayers)
end

local function tryStartMode(modeId)
	if GameMatchState.isArenaBusy() then
		broadcastMode(modeId)
		return
	end

	pruneQueue(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local list = getQueueList(modeId)
	if #list < mode.minPlayers then
		return
	end

	if modeId == "ffa" and #list < mode.maxPlayers and mode.fillTimeout then
		if fillThreads[modeId] then
			broadcastMode(modeId)
			return
		end

		fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
		local token = fillTokens[modeId]
		fillThreads[modeId] = true
		broadcastMode(modeId)

		task.delay(mode.fillTimeout, function()
			if token ~= fillTokens[modeId] then
				return
			end
			fillThreads[modeId] = nil
			if GameMatchState.isArenaBusy() then
				broadcastMode(modeId)
				return
			end

			local matchPlayers = popMatchPlayers(modeId)
			if matchPlayers then
				launchMatch(modeId, matchPlayers)
			end
		end)
		return
	end

	local matchPlayers = popMatchPlayers(modeId)
	if matchPlayers then
		launchMatch(modeId, matchPlayers)
	end
end

local function tryStartAllModes()
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end

	if playerMode[player] then
		if playerMode[player] == modeId then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
			return true
		end
		removeFromAllQueues(player)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	broadcastMode(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	removeFromAllQueues(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onArenaFreed()
	broadcastAllQueues()
	tryStartAllModes()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromAllQueues(player)
end

function MatchmakingService.registerHubCallbacks(callbacks)
	hubCallbacks = callbacks or {}
end

function MatchmakingService.start()
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

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFreed()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
