local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchmakingBridge = require(script.Parent.MatchmakingBridge)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function clearQueueUi(player)
	sendQueueUpdate(player, {
		modeId = nil,
		modeLabel = "",
		count = 0,
		needed = 0,
		maxPlayers = 0,
		status = MatchmakingConfig.STATUS.Idle,
		inQueue = false,
	})
end

MatchmakingService.configure({
	onQueueUpdate = sendQueueUpdate,
	onMatchReady = function(players, modeId)
		for _, player in players do
			if player.Parent and HubService.getPhase(player) ~= "arena" then
				HubService.leaveHubForArena(player)
			end
		end
		Bindables.MatchReady:Fire(players, modeId)
	end,
})

MatchmakingBridge.register({
	joinQueue = function(player, modeId)
		if HubService.getPhase(player) == "arena" then
			return false, "Bereits in der Arena"
		end
		return MatchmakingService.joinQueue(player, modeId)
	end,
	leaveQueue = function(player)
		local left = MatchmakingService.leaveQueue(player)
		if left then
			clearQueueUi(player)
		end
		return left
	end,
	getQueueState = function(player)
		return MatchmakingService.getQueueState(player)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.suggestModeForPlayerCount(#Players:GetPlayers())
	end
	MatchmakingBridge.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingBridge.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
