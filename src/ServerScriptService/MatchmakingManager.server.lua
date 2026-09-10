local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.setCallbacks({
	onQueueUpdate = function(player, payload)
		Remotes.QueueUpdate:FireClient(player, payload)
	end,
	onMatchReady = function(payload)
		for _, player in payload.players do
			HubService.setArenaPhase(player)
		end
		Bindables.MatchReady:Fire(payload)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	local count = #Players:GetPlayers()
	local modeId = "training"
	if count >= 3 then
		modeId = "ffa"
	elseif count == 2 then
		modeId = "pvp"
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchStateService.setBusy(false)
	MatchmakingService.onArenaFreed()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
		MatchmakingService.tick()
	end
end)

print("[MatchmakingManager] Queue system ready")
