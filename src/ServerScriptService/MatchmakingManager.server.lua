local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(ReplicatedStorage.NovaBladers.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchmakingBridge = require(script.Parent.MatchmakingBridge)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded
local IsArenaBusy = Bindables.IsArenaBusy

local function getDefaultModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function isArenaBusy()
	local ok, result = pcall(function()
		return IsArenaBusy:Invoke()
	end)
	return ok and result == true
end

local function buildQueuePayload(modeId, player)
	local snapshot = MatchmakingService.getQueueSnapshot(modeId)
	if not snapshot then
		return nil
	end

	local config = MatchmakingConfig.MODES[modeId]
	local status = "waiting"
	if isArenaBusy() then
		status = "pending"
	elseif snapshot.count >= config.minPlayers then
		if config.fillTimeout and snapshot.count < config.maxPlayers then
			status = "filling"
		else
			status = "ready"
		end
	end

	return {
		modeId = modeId,
		label = snapshot.label,
		count = snapshot.count,
		minPlayers = snapshot.minPlayers,
		maxPlayers = snapshot.maxPlayers,
		status = status,
		inQueue = player ~= nil and MatchmakingService.getPlayerMode(player) == modeId,
	}
end

local function notifyQueue(modeId)
	local snapshot = MatchmakingService.getQueueSnapshot(modeId)
	if not snapshot then
		return
	end

	for _, player in snapshot.players do
		if player.Parent then
			QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function notifyPlayerLeftQueue(player)
	if player.Parent then
		QueueUpdate:FireClient(player, {
			modeId = nil,
			status = "idle",
			inQueue = false,
		})
	end
end

local function tryStartMatch(modeId)
	if not MatchmakingService.isReadyToStart(modeId, isArenaBusy()) then
		return
	end

	local players, resolvedMode = MatchmakingService.popReadyPlayers(modeId)
	if not players or #players == 0 then
		return
	end

	local activePlayers = {}
	for _, player in players do
		if player.Parent then
			table.insert(activePlayers, player)
		end
	end

	if #activePlayers == 0 then
		return
	end

	for _, player in activePlayers do
		notifyPlayerLeftQueue(player)
	end

	MatchReady:Fire(activePlayers, resolvedMode)
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getDefaultModeId()
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	local ok = MatchmakingService.joinQueue(player, modeId)
	if not ok then
		return
	end

	notifyQueue(modeId)
	tryStartMatch(modeId)
end

local function leaveQueue(player)
	local modeId = MatchmakingService.getPlayerMode(player)
	if not modeId then
		return
	end

	MatchmakingService.leaveQueue(player)
	notifyPlayerLeftQueue(player)
	notifyQueue(modeId)
end

QueueJoin.OnServerEvent:Connect(function(player, modeId)
	joinQueue(player, modeId)
end)

QueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

MatchEnded.Event:Connect(function()
	for _, modeId in MatchmakingService.getAllQueuedModes() do
		notifyQueue(modeId)
		tryStartMatch(modeId)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local modeId = MatchmakingService.getPlayerMode(player)
	if modeId then
		MatchmakingService.removePlayer(player)
		task.defer(function()
			notifyQueue(modeId)
			tryStartMatch(modeId)
		end)
	end
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_POLL_INTERVAL)
		for _, modeId in MatchmakingService.getAllQueuedModes() do
			notifyQueue(modeId)
			tryStartMatch(modeId)
		end
	end
end)

MatchmakingBridge.register({
	joinQueue = joinQueue,
	leaveQueue = leaveQueue,
})

print("[MatchmakingManager] Queue system ready")
