local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init(Remotes, function(modeId, playerList)
	for _, player in playerList do
		HubService.leaveHubForArena(player)
	end
	Bindables.MatchReady:Fire(modeId, playerList)
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
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

task.spawn(function()
	while true do
		task.wait(0.5)
		MatchmakingService.processQueues()
	end
end)

print("[MatchmakingServer] Queue system ready")
