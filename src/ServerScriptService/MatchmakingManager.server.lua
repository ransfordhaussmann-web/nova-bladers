local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchState = require(script.Parent.MatchState)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function sendQueueUpdate(player, payload)
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function preparePlayersForMatch(matchPlayers)
	for _, player in matchPlayers do
		HubService.leaveHubForArena(player)
	end
end

MatchmakingService.init({
	onMatchReady = function(matchPlayers, modeId)
		MatchState.setBusy(true)
		preparePlayersForMatch(matchPlayers)
		Bindables.MatchReady:Fire(matchPlayers, modeId)
	end,
	onQueueUpdate = sendQueueUpdate,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getSuggestedMode(#Players:GetPlayers())
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.JoinQueue.Event:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getSuggestedMode(#Players:GetPlayers())
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchState.setBusy(false)
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_TICK)
		MatchmakingService.tick()
	end
end)

print("[MatchmakingManager] Queue system ready")
