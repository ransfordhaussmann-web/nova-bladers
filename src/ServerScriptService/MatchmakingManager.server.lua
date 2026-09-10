local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.registerHandlers({
	onQueueUpdate = function(player, payload)
		Remotes.QueueUpdate:FireClient(player, payload)
	end,
	onMatchReady = function(matchPlayers, modeId)
		for _, player in matchPlayers do
			HubService.enterArena(player)
		end
		Bindables.MatchReady:Fire(matchPlayers, modeId)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) == "string" and modeId ~= "" then
		MatchmakingService.joinQueue(player, modeId)
	else
		MatchmakingService.joinRecommendedQueue(player)
	end
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	MatchmakingService.joinRecommendedQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.clearPlayer(player)
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		MatchmakingService.tick()
	end
end)

print("[MatchmakingManager] Queue system ready")
