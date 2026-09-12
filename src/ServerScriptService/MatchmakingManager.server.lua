local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchmakingBridge = require(script.Parent.MatchmakingBridge)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.registerCallbacks({
	onMatchReady = function(modeId, players)
		for _, player in players do
			HubService.prepareForArena(player)
		end
		MatchmakingBridge.onMatchReady(modeId, players)
		Bindables.MatchReady:Fire(modeId, players)
	end,
	onQueueUpdate = function(player, payload)
		MatchmakingBridge.onQueueUpdate(player, payload)
		Remotes.QueueUpdate:FireClient(player, payload)
	end,
	onQueueLeft = function(player)
		MatchmakingBridge.onQueueLeft(player)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.isValidMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
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
	MatchmakingService.onMatchEnded()
end)

print("[MatchmakingManager] Queue system ready")
