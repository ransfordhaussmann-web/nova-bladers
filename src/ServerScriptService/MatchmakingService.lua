local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local fillTimers = {}
local started = false
local onLeaveHub

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function playerNameList(players)
	local names = {}
	for _, player in players do
		table.insert(names, player.Name)
	end
	return names
end

local function buildQueuePayload(player, modeId, status)
	local mode = getMode(modeId)
	local queued = MatchStateService.getPlayersInMode(modeId)
	local payload = {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		status = status or "waiting",
		queuedCount = #queued,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		players = playerNameList(queued),
		arenaBusy = MatchStateService.isArenaBusy(),
	}

	if player then
		payload.inQueue = MatchStateService.isQueued(player)
	end

	return payload
end

local function broadcastQueue(modeId)
	local queued = MatchStateService.getPlayersInMode(modeId)
	for _, player in queued do
		if player.Parent then
			local status = "waiting"
			if MatchStateService.isArenaBusy() then
				status = "pending"
			end
			QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
		end
	end
end

local function broadcastAllQueues()
	for _, mode in MatchModes.getAll() do
		broadcastQueue(mode.id)
	end
end

local function cancelFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function clearQueueForPlayers(players)
	for _, player in players do
		MatchStateService.clearPlayer(player)
	end
end

local function launchMatch(modeId, players)
	cancelFillTimer(modeId)
	clearQueueForPlayers(players)

	if MatchStateService.isArenaBusy() then
		MatchStateService.setPendingMatch({
			modeId = modeId,
			players = players,
		})
		for _, player in players do
			if player.Parent then
				QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, "pending"))
			end
		end
		return
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(modeId, players)
end

local function buildRoster(players, maxPlayers)
	local roster = {}
	for i = 1, math.min(#players, maxPlayers) do
		table.insert(roster, players[i])
	end
	return roster
end

local function shouldStartImmediately(mode, players)
	local count = #players
	if count >= mode.maxPlayers then
		return true
	end
	if mode.id == "training" and count >= 1 then
		return true
	end
	if mode.id == "pvp" and count >= 2 then
		return true
	end
	return false
end

local function scheduleFillTimeout(modeId, mode)
	if not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		local players = MatchStateService.getPlayersInMode(modeId)
		if #players >= mode.minPlayers then
			launchMatch(modeId, buildRoster(players, mode.maxPlayers))
		end
	end)
end

local function evaluateMode(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local players = MatchStateService.getPlayersInMode(modeId)
	broadcastQueue(modeId)

	if shouldStartImmediately(mode, players) then
		launchMatch(modeId, buildRoster(players, mode.maxPlayers))
		return
	end

	if mode.id == "ffa" and #players >= mode.minPlayers then
		scheduleFillTimeout(modeId, mode)
	elseif mode.id == "training" and #players >= 1 then
		cancelFillTimer(modeId)
		fillTimers[modeId] = task.delay(MatchmakingConfig.TRAINING_START_DELAY, function()
			fillTimers[modeId] = nil
			local queued = MatchStateService.getPlayersInMode(modeId)
			if #queued >= 1 then
				launchMatch(modeId, { queued[1] })
			end
		end)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if MatchStateService.isQueued(player) then
		local current = MatchStateService.getQueueMode(player)
		if current == modeId then
			return true, "already_queued"
		end
		MatchmakingService.leaveQueue(player)
	end

	MatchStateService.setQueued(player, modeId)
	if onLeaveHub then
		onLeaveHub(player)
	end

	evaluateMode(modeId)
	return true, "joined"
end

function MatchmakingService.leaveQueue(player)
	local modeId = MatchStateService.getQueueMode(player)
	if not modeId then
		return
	end

	MatchStateService.clearPlayer(player)
	cancelFillTimer(modeId)
	QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.recommendForPlayerCount(count)
	return MatchmakingService.joinQueue(player, mode.id)
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	local pending = MatchStateService.getPendingMatch()
	if pending then
		MatchStateService.clearPendingMatch()
		launchMatch(pending.modeId, pending.players)
		return
	end
	broadcastAllQueues()
end

function MatchmakingService.onPlayerRemoving(player)
	local modeId = MatchStateService.getQueueMode(player)
	MatchStateService.clearPlayer(player)
	if modeId then
		cancelFillTimer(modeId)
		broadcastQueue(modeId)
	end
end

function MatchmakingService.start(options)
	if started then
		return
	end
	started = true
	onLeaveHub = options and options.onLeaveHub

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
