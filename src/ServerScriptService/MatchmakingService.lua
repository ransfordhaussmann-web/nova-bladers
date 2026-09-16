local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local started = false
local pendingMatch = nil

local function getMode(modeId)
	return MatchModes.get(modeId) or MatchModes.training
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function playerName(player)
	return player.DisplayName or player.Name
end

local function buildQueueNames(modeId)
	local names = {}
	for _, entry in ensureQueue(modeId) do
		if entry.player.Parent then
			table.insert(names, playerName(entry.player))
		end
	end
	return names
end

local function buildUpdatePayload(player, modeId, status)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		queued = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		players = buildQueueNames(modeId),
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function sendQueueUpdate(player, modeId, status)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId, status))
	end
end

local function broadcastQueue(modeId)
	for _, entry in ensureQueue(modeId) do
		local status = "waiting"
		if pendingMatch and pendingMatch.modeId == modeId then
			status = "pending"
		end
		sendQueueUpdate(entry.player, modeId, status)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i = #queue, 1, -1 do
		if queue[i].player == player then
			table.remove(queue, i)
		end
	end

	playerQueue[player] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	broadcastQueue(modeId)
end

local function leaveHubForArena(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	HubService.leaveHubForArena(player)
end

local function launchMatch(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
		leaveHubForArena(player)
	end

	if MatchReady then
		MatchReady:Fire(modeId, playerList)
	end
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)

	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		pendingMatch = {
			modeId = modeId,
			players = {},
		}
		for i = 1, math.min(#queue, mode.maxPlayers) do
			table.insert(pendingMatch.players, queue[i].player)
		end
		broadcastQueue(modeId)
		return
	end

	local playerList = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(playerList, queue[i].player)
	end

	launchMatch(modeId, playerList)
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end

		local queue = ensureQueue(modeId)
		if #queue >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end

	removeFromQueue(player)

	local queue = ensureQueue(modeId)
	table.insert(queue, {
		player = player,
		joinedAt = os.clock(),
	})

	playerQueue[player] = modeId
	sendQueueUpdate(player, modeId, "waiting")
	broadcastQueue(modeId)

	local mode = getMode(modeId)
	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #queue == mode.minPlayers then
		scheduleFillTimer(modeId)
	elseif mode.minPlayers == 1 then
		tryStartMatch(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	if pendingMatch then
		local snapshot = pendingMatch
		pendingMatch = nil

		local valid = {}
		for _, player in snapshot.players do
			if player.Parent and playerQueue[player] == snapshot.modeId then
				table.insert(valid, player)
			end
		end

		local mode = getMode(snapshot.modeId)
		if #valid >= mode.minPlayers and not MatchStateService.isBusy() then
			launchMatch(snapshot.modeId, valid)
			return
		end
	end

	for modeId, _ in pairs(queues) do
		local queue = ensureQueue(modeId)
		local mode = getMode(modeId)
		if #queue >= mode.minPlayers then
			tryStartMatch(modeId)
			break
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

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
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
