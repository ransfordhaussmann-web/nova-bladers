local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.setHandlers({
	onMatchReady = function(payload)
		for _, player in payload.players do
			HubService.leaveHubForMatch(player)
		end
		Bindables.MatchReady:Fire(payload)
	end,
	onQueueChanged = function(player, state)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, state)
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

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

task.spawn(function()
	while true do
		task.wait(2)
		MatchmakingService.pruneDisconnected()
	end
end)

print("[MatchmakingManager] Queue system ready")
