local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerQueue = {}
local fillTokens = {}
local callbacks = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getQueueStatus(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = ensureQueue(modeId)
	local count = #queue
	local status = "waiting"

	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif count >= mode.minPlayers and mode.fillTimeout > 0 and count < mode.maxPlayers then
		status = "filling"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		label = mode.label,
		count = count,
		min = mode.minPlayers,
		max = mode.maxPlayers,
		status = status,
		fillTimeout = mode.fillTimeout,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = getQueueStatus(modeId)
	if not payload then
		return
	end

	for _, player in ensureQueue(modeId) do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = ensureQueue(modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	broadcastQueueUpdate(modeId)
end

local function removePlayersFromQueue(modeId, playerList)
	local queue = ensureQueue(modeId)
	local removeSet = {}
	for _, player in playerList do
		removeSet[player] = true
		playerQueue[player] = nil
	end

	local i = 1
	while i <= #queue do
		if removeSet[queue[i]] then
			table.remove(queue, i)
		else
			i += 1
		end
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	removePlayersFromQueue(modeId, playerList)
	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		if player.Parent and callbacks.onMatchStart then
			callbacks.onMatchStart(player)
		end
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})

	for modeKey in queues do
		broadcastQueueUpdate(modeKey)
	end
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.maxPlayers > 0 and #queue >= mode.maxPlayers then
		local players = {}
		for i = 1, mode.maxPlayers do
			table.insert(players, queue[i])
		end
		launchMatch(modeId, players)
		return
	end

	if mode.fillTimeout <= 0 or #queue >= mode.maxPlayers then
		local players = {}
		for i = 1, math.min(#queue, mode.maxPlayers) do
			table.insert(players, queue[i])
		end
		launchMatch(modeId, players)
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	broadcastQueueUpdate(modeId)

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if MatchStateService.isArenaBusy() then
			return
		end

		local currentQueue = ensureQueue(modeId)
		if #currentQueue < mode.minPlayers then
			return
		end

		local players = {}
		for i = 1, math.min(#currentQueue, mode.maxPlayers) do
			table.insert(players, currentQueue[i])
		end
		launchMatch(modeId, players)
	end)
end

local function resolveModeId(modeId)
	if modeId == "auto" or modeId == nil then
		return MatchModes.getRecommended(#Players:GetPlayers()).id
	end
	return modeId
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false, "invalid_player"
	end

	modeId = resolveModeId(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		return true, "already_queued"
	end

	clearPlayerFromQueues(player)

	local queue = ensureQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, getQueueStatus(modeId))
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)

	return true, "joined"
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	clearPlayerFromQueues(player)
	return true
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)

	task.delay(MatchmakingConfig.PENDING_RETRY_DELAY, function()
		for modeId in queues do
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.onPlayerRemoving(player)
	clearPlayerFromQueues(player)
end

function MatchmakingService.init(hubCallbacks)
	callbacks = hubCallbacks or {}
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
