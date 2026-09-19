local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

MatchmakingService.register({
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
	onQueueLeft = function(player)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { status = "left" })
		end
	end,
	onMatchReady = function(modeId, matchPlayers)
		MatchStateService.setArenaBusy(true)
		MatchReady:Fire(modeId, matchPlayers)
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

MatchEnded.Event:Connect(function()
	MatchStateService.setArenaBusy(false)
	task.defer(function()
		MatchmakingService.onArenaFreed()
	end)
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
		MatchmakingService.tick()
	end
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
