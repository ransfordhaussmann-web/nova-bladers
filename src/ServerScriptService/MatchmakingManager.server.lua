local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.configure({
	remotes = Remotes,
	bindables = Bindables,
})

local function isValidMode(modeId)
	return MatchmakingConfig.getMode(modeId) ~= nil
end

local function isValidMode(modeId)
	return MatchmakingConfig.getMode(modeId) ~= nil
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or not isValidMode(modeId) then
		modeId = MatchmakingService.getRecommendedModeId()
	end
	if HubService.getPhase(player) ~= "hub" and HubService.getPhase(player) ~= "queue" then
		return
	end
	if HubService.getPhase(player) == "queue" then
		MatchmakingService.leaveQueue(player)
	end

	local ok = MatchmakingService.joinQueue(player, modeId)
	if ok then
		HubService.setPhase(player, "queue")
	end
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	if HubService.getPhase(player) == "queue" then
		HubService.setPhase(player, "hub")
	end
end)

Bindables.MatchReady.Event:Connect(function(playerList)
	for _, player in playerList do
		if player.Parent then
			HubService.setPhase(player, "arena")
		end
	end
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
