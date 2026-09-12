local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local function leaveHubForArena(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	HubService.leaveHubForArena(player)
end

local function onQueueChanged(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function onMatchReady(roster, modeId)
	for _, player in roster do
		leaveHubForArena(player)
	end
	MatchReady:Fire(roster, modeId)
end

MatchmakingService.setCallbacks({
	onMatchReady = onMatchReady,
	onQueueChanged = onQueueChanged,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getActiveModeId(#Players:GetPlayers())
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.clearPlayer(player)
end)

RunService.Heartbeat:Connect(function()
	MatchmakingService.tick()
end)

print("[MatchmakingManager] Queue system ready")
