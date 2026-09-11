local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function sendQueueUpdate(target, payload, isPersonal)
	if not target or not target.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(target, payload, isPersonal)
end

MatchmakingService.setCallbacks({
	onQueueUpdate = sendQueueUpdate,
	onMatchReady = function(modeId, playerList)
		Bindables.MatchReady:Fire(modeId, playerList)
	end,
})

local function joinQueue(player, modeId)
	return MatchmakingService.joinQueue(player, modeId)
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	local modeId = MatchmakingService.getQuickMatchMode(#Players:GetPlayers())
	joinQueue(player, modeId)
end)

Bindables.MatchStarted.Event:Connect(function()
	MatchmakingService.setArenaBusy(true)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.removePlayer(player)
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		MatchmakingService.tick()
	end
end)

print("[MatchmakingManager] Queue system ready")
