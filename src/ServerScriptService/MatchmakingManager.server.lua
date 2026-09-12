local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(ReplicatedStorage.NovaBladers.MatchmakingService)
local MatchmakingBridge = require(ReplicatedStorage.NovaBladers.MatchmakingBridge)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local service = MatchmakingService.new(MatchmakingConfig, Remotes, Bindables)
MatchmakingBridge.register(service)

local function resolveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = resolveModeId()
	end
	service:joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	service:removeFromQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	service:onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	service:onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
