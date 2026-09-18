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

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local initialized = false

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	if queue then
		for i, p in queue do
			if p == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil
end

local function queuePosition(modeId, player)
	local queue = getQueue(modeId)
	if not queue then
		return 0
	end
	for i, p in queue do
		if p == player then
			return i
		end
	end
	return 0
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local count = queue and #queue or 0
	local status = "waiting"

	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif mode and count >= mode.minPlayers then
		status = "ready"
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		position = queuePosition(entry.modeId, player),
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(player)
	if player.Parent and Remotes then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllQueued()
	for player, _ in playerQueue do
		if player.Parent then
			broadcastQueueUpdate(player)
		end
	end
end

local function cancelFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	cancelFillTimer(modeId)
	local token = {}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or not queue then
		return false
	end

	if MatchStateService.isArenaBusy() then
		broadcastAllQueued()
		return false
	end

	local players = {}
	for _, player in queue do
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(players, player)
			if #players >= mode.maxPlayers then
				break
			end
		end
	end

	if #players < mode.minPlayers then
		return false
	end

	cancelFillTimer(modeId)

	for _, player in players do
		removeFromQueue(player)
	end

	for _, player in players do
		HubService.leaveHubForArena(player)
		broadcastQueueUpdate(player)
	end

	MatchReady:Fire(players)
	return true
end

function MatchmakingService.onArenaFree()
	MatchStateService.setArenaBusy(false)
	broadcastAllQueued()

	for modeId, _ in queues do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end

	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	if MatchStateService.isArenaBusy() and modeId == "training" then
		-- Training can still queue but will be pending until arena is free.
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = { modeId = modeId }

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if mode.fillTimeout and #queue >= mode.minPlayers and #queue < mode.maxPlayers then
		startFillTimer(modeId)
	elseif #queue >= mode.maxPlayers then
		cancelFillTimer(modeId)
		MatchmakingService.tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers and not mode.fillTimeout then
		MatchmakingService.tryStartMatch(modeId)
	end

	broadcastAllQueued()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if mode and mode.fillTimeout and queue and #queue < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueueUpdate(player)
	broadcastAllQueued()
	return true
end

function MatchmakingService.getActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getActiveModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
