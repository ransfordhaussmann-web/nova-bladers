local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getSuggestedMode()
	end

	local ok = MatchmakingService.joinQueue(player, modeId)
	if ok then
		HubService.setQueuePhase(player, modeId)
	end
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	if HubService.clearQueuePhase then
		HubService.clearQueuePhase(player)
	end
end)

MatchmakingService.setMatchStartHandler(function(players, _modeId)
	for _, player in players do
		if HubService.leaveHubForArena then
			HubService.leaveHubForArena(player)
		end
	end
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onArenaFreed()
end)

print("[Matchmaking] Queue system ready")
