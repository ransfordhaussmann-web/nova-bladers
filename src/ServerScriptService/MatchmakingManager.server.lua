local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function broadcastQueueUpdate(player, payload)
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function leaveHubForMatch(player)
	if HubService.leaveHubForArena then
		HubService.leaveHubForArena(player)
	end
end

MatchmakingService.registerHandlers({
	onQueueUpdate = broadcastQueueUpdate,
	onMatchReady = function(modeId, playerList)
		for _, player in playerList do
			leaveHubForMatch(player)
		end
		Bindables.MatchReady:Fire(modeId, playerList)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if typeof(modeId) ~= "string" or modeId == "" then
		modeId = MatchmakingService.getRecommendedMode(#Players:GetPlayers())
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
