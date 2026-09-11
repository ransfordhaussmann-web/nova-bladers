local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function leaveHubForArena(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	if HubService.leaveHubForArena then
		HubService.leaveHubForArena(player)
	end
end

MatchmakingService.setOnUpdate(function(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end)

MatchmakingService.setOnReady(function(payload)
	MatchmakingService.setArenaBusy(true)

	for _, player in payload.players do
		leaveHubForArena(player)
	end

	Bindables.MatchReady:Fire(payload)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getRecommendedMode(#Players:GetPlayers())
	end

	if HubService.getPhase(player) == "arena" then
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

print("[MatchmakingManager] Queue system ready")
