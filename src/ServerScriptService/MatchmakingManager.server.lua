local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchCoordinator = require(script.Parent.MatchCoordinator)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchCoordinator.configure({ bindables = Bindables })

MatchmakingService.configure({
	remotes = Remotes,
	onStartMatch = function(players, modeId)
		MatchCoordinator.startMatch(players, modeId)
	end,
})

MatchStateService.onArenaIdle(function()
	MatchmakingService.onArenaIdle()
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.isValidMode(modeId) then
		modeId = MatchCoordinator.resolveAutoMode(#Players:GetPlayers())
	end
	HubService.enterQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	if HubService.getPhase(player) == "queued" then
		HubService.returnPlayerToHub(player)
	end
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
