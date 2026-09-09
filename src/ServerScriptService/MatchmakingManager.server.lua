local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

MatchmakingService.registerHandlers({
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
	onMatchReady = function(players, modeId)
		for _, player in players do
			if player.Parent then
				HubService.prepareForMatch(player)
			end
		end
		MatchReady:Fire(players, modeId)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

MatchEnded.Event:Connect(function()
	MatchStateService.setArenaBusy(false)
	task.defer(function()
		MatchmakingService.onArenaFreed()
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.clearPlayer(player)
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
