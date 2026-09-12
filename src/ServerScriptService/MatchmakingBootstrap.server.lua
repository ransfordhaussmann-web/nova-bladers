local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	local ok = MatchmakingService.joinQueue(player, modeId)
	if ok then
		-- Player stays in hub while waiting; arena phase starts when match is ready.
	end
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchReady.Event:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.players) ~= "table" then
		return
	end

	for _, player in payload.players do
		if player.Parent and HubService.getPhase(player) == "hub" then
			HubService.setArenaPhase(player)
		end
	end
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

print("[Matchmaking] Queue system ready")
