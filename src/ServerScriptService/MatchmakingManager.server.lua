local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingBridge = require(ReplicatedStorage.NovaBladers.MatchmakingBridge)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init(Remotes, Bindables)

MatchmakingBridge.register({
	joinQueue = function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end,
	leaveQueue = function(player)
		MatchmakingService.leaveQueue(player)
	end,
	isArenaBusy = function()
		return MatchmakingService.isArenaBusy()
	end,
	onMatchStarted = function(_players, _modeId)
		-- HubManager handles arena phase via its own MatchReady listener
	end,
	onMatchEnded = function()
		MatchmakingService.onMatchEnded()
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or modeId == "" then
		modeId = MatchmakingService.getActiveModeForServer()
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
