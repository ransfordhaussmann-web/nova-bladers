local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

MatchmakingService.register({
	onPlayerQueued = function(player, modeId)
		HubService.markQueued(player, modeId)
	end,
	onPlayerLeftQueue = function(player)
		HubService.markHub(player)
	end,
	onMatchReady = function(player, modeId)
		HubService.markArena(player, modeId)
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
