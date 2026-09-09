local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init(Remotes, Bindables, function(playerList, modeId)
	for _, player in playerList do
		HubService.leaveHubForMatch(player, modeId)
	end
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	local modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
	MatchmakingService.joinQueue(player, modeId)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[Matchmaking] Queue system ready")
