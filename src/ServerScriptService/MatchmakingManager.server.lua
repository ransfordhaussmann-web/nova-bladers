local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.registerCallbacks({
	onQueueUpdateSingle = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
	onQueueUpdate = function(payload)
		for player, update in payload do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, update)
			end
		end
	end,
	onQueueLeft = function(player)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end,
	onMatchReady = function(players, modeId)
		for _, player in players do
			HubService.setArenaPhase(player)
		end
		Bindables.MatchReady:Fire({
			players = players,
			mode = modeId,
		})
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.getRecommendedModeId(#Players:GetPlayers())
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchStarted.Event:Connect(function()
	MatchmakingService.setArenaBusy(true)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.removePlayer(player)
end)

print("[MatchmakingManager] Queue system ready")
