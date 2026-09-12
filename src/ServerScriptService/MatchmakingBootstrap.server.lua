local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.registerCallbacks({
	onPlayersEnterArena = function(players)
		HubService.preparePlayersForMatch(players)
	end,
	onMatchReady = function(payload)
		Bindables.MatchReady:Fire(payload)
	end,
})

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = "auto"
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[Matchmaking] Queue system ready")
