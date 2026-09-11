local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.register({
	getPhase = function(player)
		return HubService.getPhase(player)
	end,
	getRecommendedMode = function()
		return MatchmakingService.getRecommendedMode(#Players:GetPlayers())
	end,
	onPlayerEnterArena = function(player)
		if HubService.enterArena then
			HubService.enterArena(player)
		end
	end,
	onMatchReady = function(players, modeId)
		Bindables.MatchReady:Fire(players, modeId)
	end,
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

print("[MatchmakingServer] Queue ready — Training / PvP / FFA")
