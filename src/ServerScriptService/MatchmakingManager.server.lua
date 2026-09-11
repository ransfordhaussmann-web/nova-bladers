local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function joinQueue(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if typeof(modeId) ~= "string" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) == "string" then
		joinQueue(player, modeId)
	else
		local count = #game:GetService("Players"):GetPlayers()
		local activeMode = if count >= 3 then "ffa" elseif count == 2 then "pvp" else "training"
		joinQueue(player, activeMode)
	end
end)

Bindables.MatchReady.Event:Connect(function(matchPlayers)
	for _, player in matchPlayers do
		if player.Parent then
			HubService.leaveHubForArena(player)
		end
	end
end)

print("[MatchmakingManager] Queue system ready")
