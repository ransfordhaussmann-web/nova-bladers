local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.setHandlers({
	onMatchReady = function(players, modeId)
		for _, player in players do
			HubService.leaveHubForMatch(player, modeId)
		end
		Bindables.MatchReady:Fire(players, modeId)
	end,
	onQueueChanged = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

print("[MatchmakingManager] Queue system ready")
