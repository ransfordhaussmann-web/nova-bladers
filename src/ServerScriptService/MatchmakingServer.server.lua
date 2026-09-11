local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init({
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
	onQueueLeft = function(player)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end,
	onMatchReady = function(playerList, modeId)
		for _, player in playerList do
			HubService.prepareForMatch(player)
		end
		Bindables.MatchReady:Fire(playerList, modeId)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.removePlayer(player)
end)

print("[MatchmakingServer] Queue ready — Training / PvP / FFA")
