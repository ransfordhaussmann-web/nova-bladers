local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local function sendQueueUpdate(player, payload)
	Remotes.QueueUpdate:FireClient(player, payload)
end

MatchmakingService.register({
	onQueueUpdate = sendQueueUpdate,
	onQueueLeft = function(player)
		sendQueueUpdate(player, { status = "idle" })
	end,
	onMatchReady = function(players, modeId)
		for _, player in players do
			if player.Parent then
				HubService.prepareForMatch(player)
			end
		end
		Bindables.MatchReady:Fire(players, modeId)
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

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
