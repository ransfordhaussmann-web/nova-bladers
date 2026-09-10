local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function leaveHubForArena(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	if HubService.markArena then
		HubService.markArena(player)
	end
end

MatchmakingService.setCallbacks({
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
	onMatchReady = function(modeId, playerList)
		MatchmakingService.setArenaBusy(true)
		for _, player in playerList do
			leaveHubForArena(player)
		end
		Bindables.MatchReady:Fire(modeId, playerList)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.getMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.removePlayer(player)
end)

Bindables.MatchStarted.Event:Connect(function()
	MatchmakingService.setArenaBusy(true)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

print("[MatchmakingManager] Queue system ready")
