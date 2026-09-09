local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init({
	remotes = Remotes,
	bindables = Bindables,
	hubCallbacks = {
		enterArenaPhase = HubService.enterArenaPhase,
		leaveQueuePhase = HubService.leaveQueuePhase,
	},
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
		modeId = MatchmakingService.getSuggestedMode(#Players:GetPlayers())
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.handlePlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
