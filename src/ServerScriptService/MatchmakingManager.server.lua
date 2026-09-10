local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local function joinQueue(player, modeId)
	if MatchmakingService.getPlayerMode(player) then
		MatchmakingService.leave(player)
	end

	local ok, reason = MatchmakingService.join(player, modeId)
	if not ok then
		QueueUpdate:FireClient(player, { inQueue = false, error = reason })
		return false
	end

	QueueUpdate:FireClient(player, MatchmakingService.buildPlayerUpdate(player))
	MatchmakingService.processQueues()
	return true
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if MatchmakingService.getPlayerMode(player) then
			QueueUpdate:FireClient(player, MatchmakingService.buildPlayerUpdate(player))
		end
	end
end

QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.resolveAutoMode(#Players:GetPlayers())
	end
	joinQueue(player, modeId)
end)

QueueLeave.OnServerEvent:Connect(function(player)
	if MatchmakingService.leave(player) then
		QueueUpdate:FireClient(player, { inQueue = false })
	end
end)

MatchmakingService.onQueueUpdate(broadcastQueueUpdates)

MatchmakingService.onMatchReady(function(batch, modeId)
	for _, player in batch do
		HubService.leaveHubForArena(player)
	end
	MatchReady:Fire(batch, modeId)
end)

MatchEnded.Event:Connect(function()
	MatchStateService.setBusy(false)
	MatchStateService.signalArenaFree()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leave(player)
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_TICK)
		MatchmakingService.processQueues()
		broadcastQueueUpdates()
	end
end)

print("[MatchmakingManager] Queue system ready")
