local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local function broadcastQueueState(targetPlayer)
	local payload = MatchmakingService.getPlayerState(targetPlayer)
	Remotes.MatchQueueState:FireClient(targetPlayer, payload)
end

local function broadcastAllQueueStates()
	for _, player in Players:GetPlayers() do
		if HubService.getPhase(player) == "hub" then
			broadcastQueueState(player)
		end
	end
end

local function leaveHubForMatch(player)
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	HubService.leaveHubForArena(player)
end

MatchmakingService.onMatchReady(function(modeId, playerList)
	for _, player in playerList do
		leaveHubForMatch(player)
	end
	broadcastAllQueueStates()
	Bindables.StartMatch:Fire(modeId, playerList)
end)

Remotes.JoinMatchQueue.OnServerEvent:Connect(function(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
	end

	local ok = MatchmakingService.joinQueue(player, modeId)
	if ok then
		broadcastAllQueueStates()
	end
end)

Remotes.LeaveMatchQueue.OnServerEvent:Connect(function(player)
	if MatchmakingService.leaveQueue(player) then
		broadcastAllQueueStates()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.clearPlayer(player)
	task.defer(broadcastAllQueueStates)
end)

print("[MatchmakingManager] Queue ready — use mode pads or portal to join")
