local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= MatchmakingConfig.MODES.ffa.minPlayers then
		return "ffa"
	elseif count >= MatchmakingConfig.MODES.pvp.minPlayers then
		return "pvp"
	end
	return "training"
end

local function joinQueue(player, modeId)
	local phase = HubService.getPhase(player)
	if phase ~= "hub" and phase ~= "queue" then
		return
	end
	if MatchmakingService.join(player, modeId) then
		HubService.markQueued(player, modeId)
	end
end

MatchmakingService.setCallbacks({
	onQueueUpdate = function(player, snapshot)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, snapshot)
		end
	end,
	onMatchReady = function(payload)
		for _, matchPlayer in payload.players do
			HubService.leaveHubForMatch(matchPlayer)
		end
		Bindables.MatchReady:Fire(payload)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getRecommendedModeId()
	end
	if not MatchmakingConfig.MODES[modeId] then
		modeId = getRecommendedModeId()
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	if MatchmakingService.leave(player) then
		HubService.markHub(player)
	end
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.handleMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.handlePlayerRemoving(player)
end)

MatchStateService.onArenaFree(function()
	MatchmakingService.broadcastAllQueued()
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
