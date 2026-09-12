local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingBridge = require(script.Parent.MatchmakingBridge)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingBridge.init(function(player, status)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, status)
	end
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingBridge.getRecommendedModeId()
	end
	MatchmakingBridge.joinMode(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingBridge.leave(player)
end)

Bindables.IsArenaBusy.OnInvoke = function()
	return MatchmakingBridge.isArenaBusy()
end

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingBridge.onMatchEnded()
end)

print("[MatchmakingManager] Queue system ready")
