local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local function resolveModeId(modeId)
	if modeId == MatchmakingConfig.PORTAL_MODE or modeId == "auto" or modeId == nil then
		return MatchmakingService.resolveAutoMode()
	end
	return modeId
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	local resolvedMode = resolveModeId(modeId)
	MatchmakingService.joinQueue(player, resolvedMode)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

print("[MatchmakingManager] Queue system ready")
