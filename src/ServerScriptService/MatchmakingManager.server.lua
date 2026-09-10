local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init(Remotes, Bindables, function(players, _modeId)
	for _, player in players do
		if player.Parent and HubService.prepareForArena then
			HubService.prepareForArena(player)
		end
	end
end)

local function resolveModeId(modeId)
	if typeof(modeId) == "string" and modeId ~= "" then
		return modeId
	end
	return nil
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	local resolved = resolveModeId(modeId)
	if not resolved then
		return
	end
	MatchmakingService.joinQueue(player, resolved)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
