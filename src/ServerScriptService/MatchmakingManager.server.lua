local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingBridge = require(ReplicatedStorage.NovaBladers.MatchmakingBridge)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init({
	remotes = Remotes,
	bindables = Bindables,
	onMatchStarting = function(players)
		for _, player in players do
			HubService.leaveForArena(player)
		end
	end,
})

MatchmakingBridge.register(MatchmakingService)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
