local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil
local onLeaveHub = nil

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
	for i, p in queue do
		if p == player then
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

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.getById(modeId)
	local queue = getQueue(modeId)
	local pending = pendingMatch ~= nil and table.find(pendingMatch.players, player) ~= nil

	return {
		inQueue = true,
		pending = pending,
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = GameMatchState.isArenaBusy(),
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function launchMatch(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
	end
	broadcastQueueUpdate()

	if GameMatchState.isArenaBusy() then
		pendingMatch = { modeId = modeId, players = playerList }
		for _, player in playerList do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					inQueue = true,
					pending = true,
					modeId = modeId,
					modeLabel = MatchModes.getById(modeId).label,
					players = #playerList,
					arenaBusy = true,
				})
			end
		end
		return
	end

	GameMatchState.setArenaBusy(true)
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes.getById(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if #queue >= mode.maxPlayers then
		local matchPlayers = {}
		for i = 1, mode.maxPlayers do
			table.insert(matchPlayers, queue[i])
		end
		launchMatch(modeId, matchPlayers)
		return
	end

	if mode.fillTimeout > 0 and not fillTimers[modeId] then
		fillTimers[modeId] = task.delay(mode.fillTimeout, function()
			fillTimers[modeId] = nil
			local current = getQueue(modeId)
			if #current >= mode.minPlayers then
				local matchPlayers = {}
				for _, p in current do
					table.insert(matchPlayers, p)
				end
				launchMatch(modeId, matchPlayers)
			end
		end)
	elseif mode.fillTimeout == 0 and #queue >= mode.minPlayers then
		local matchPlayers = {}
		for _, p in queue do
			table.insert(matchPlayers, p)
		end
		launchMatch(modeId, matchPlayers)
	end
end

local function onArenaFree()
	GameMatchState.setArenaBusy(false)

	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		task.defer(function()
			launchMatch(match.modeId, match.players)
		end)
		return
	end

	broadcastQueueUpdate()

	for _, mode in MatchModes.getAll() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false
	end

	local mode = MatchModes.getById(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] == modeId then
		return true
	end

	removeFromQueue(player)
	playerQueue[player] = modeId
	table.insert(getQueue(modeId), player)

	if onLeaveHub then
		onLeaveHub(player)
	end

	broadcastQueueUpdate()
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	removeFromQueue(player)

	if pendingMatch then
		local idx = table.find(pendingMatch.players, player)
		if idx then
			table.remove(pendingMatch.players, idx)
			if #pendingMatch.players == 0 then
				pendingMatch = nil
			end
		end
	end

	broadcastQueueUpdate()
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start(options)
	Remotes, Bindables = RemotesSetup.ensure()
	onLeaveHub = options and options.onLeaveHub

	queues = {}
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {}
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.resolveAuto(#Players:GetPlayers()).id
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
