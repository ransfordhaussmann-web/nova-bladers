local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.registerHandlers({
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
	onMatchReady = function(players, modeId)
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

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.removePlayer(player)
end)

local lastTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastTick >= MatchmakingConfig.QUEUE_BROADCAST_INTERVAL then
		lastTick = now
		MatchmakingService.tick()
	end
end)

print("[MatchmakingManager] Queue system ready")
