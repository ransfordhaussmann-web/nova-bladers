local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local startTokens = {}
local remotes = nil
local onMatchReady = nil

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local cleaned = {}
	for _, player in queue do
		if isValidPlayer(player) then
			table.insert(cleaned, player)
		else
			playerQueue[player] = nil
		end
	end
	queues[modeId] = cleaned
end

local function getStatus(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	pruneQueue(modeId)

	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif #queue >= mode.minPlayers then
		status = "starting"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	pruneQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if remotes and remotes.QueueUpdate then
			remotes.QueueUpdate:FireClient(player, getStatus(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueueUpdate(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	broadcastQueueUpdate(modeId)
	return modeId
end

local function pullPlayers(modeId, count)
	pruneQueue(modeId)
	local queue = getQueue(modeId)
	local pulled = {}
	local take = math.min(count, #queue)

	for _ = 1, take do
		local player = table.remove(queue, 1)
		if isValidPlayer(player) then
			playerQueue[player] = nil
			table.insert(pulled, player)
		end
	end

	broadcastQueueUpdate(modeId)
	return pulled
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	startTokens[modeId] = (startTokens[modeId] or 0) + 1
	local token = startTokens[modeId]

	MatchStateService.setBusy(true)

	task.delay(MatchmakingConfig.START_DELAY, function()
		if token ~= startTokens[modeId] then
			return
		end

		local readyPlayers = {}
		for _, player in players do
			if isValidPlayer(player) and playerQueue[player] == nil then
				table.insert(readyPlayers, player)
			end
		end

		if #readyPlayers == 0 then
			MatchStateService.setBusy(false)
			return
		end

		if onMatchReady then
			onMatchReady(readyPlayers, modeId)
		end
	end)
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	pruneQueue(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		if fillTimers[modeId] then
			task.cancel(fillTimers[modeId])
			fillTimers[modeId] = nil
		end
		broadcastQueueUpdate(modeId)
		return
	end

	if count >= mode.maxPlayers then
		if fillTimers[modeId] then
			task.cancel(fillTimers[modeId])
			fillTimers[modeId] = nil
		end
		local players = pullPlayers(modeId, mode.maxPlayers)
		launchMatch(modeId, players)
		return
	end

	if mode.fillTimeout <= 0 then
		local players = pullPlayers(modeId, mode.maxPlayers)
		launchMatch(modeId, players)
		return
	end

	if not fillTimers[modeId] then
		fillTimers[modeId] = task.delay(mode.fillTimeout, function()
			fillTimers[modeId] = nil
			if MatchStateService.isBusy() then
				broadcastQueueUpdate(modeId)
				return
			end

			pruneQueue(modeId)
			local current = getQueue(modeId)
			if #current >= mode.minPlayers then
				local players = pullPlayers(modeId, mode.maxPlayers)
				launchMatch(modeId, players)
			else
				broadcastQueueUpdate(modeId)
			end
		end)
	end

	broadcastQueueUpdate(modeId)
end

function MatchmakingService.init(remoteFolder, matchReadyCallback)
	remotes = remoteFolder
	onMatchReady = matchReadyCallback
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false, "invalid_player"
	end

	modeId = modeId or MatchmakingConfig.DEFAULT_MODE
	if not MatchmakingConfig.MODES[modeId] then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			broadcastQueueUpdate(modeId)
			return true
		end
		removeFromQueue(player)
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	removeFromQueue(player)
	return true
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaBusyChanged()
	broadcastAllQueues()
	if not MatchStateService.isBusy() then
		for modeId in MatchmakingConfig.MODES do
			tryStartMode(modeId)
		end
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

do
	local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
	local HubService = require(script.Parent.HubService)
	local Remotes, Bindables = RemotesSetup.ensure()

	MatchmakingService.init(Remotes, function(players, modeId)
		for _, player in players do
			HubService.leaveHubForArena(player)
		end

		Bindables.MatchReady:Fire({
			players = players,
			modeId = modeId,
		})
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			local count = #Players:GetPlayers()
			if count >= 3 then
				modeId = "ffa"
			elseif count == 2 then
				modeId = "pvp"
			else
				modeId = "training"
			end
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchStateService.setBusy(false)
		MatchmakingService.onArenaBusyChanged()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
