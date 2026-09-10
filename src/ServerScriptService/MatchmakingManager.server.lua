local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		local snapshot = MatchmakingService.getPlayerSnapshot(player)
		if snapshot then
			Remotes.QueueUpdate:FireClient(player, snapshot)
		end
	end
end

local function sendQueueClear(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, nil)
	end
end

MatchmakingService.setCallbacks({
	onMatchReady = function(players, modeId)
		for _, player in players do
			if player.Parent then
				HubService.leaveForArena(player)
			end
		end
		Bindables.MatchReady:Fire(players, modeId)
	end,
	onQueueUpdate = broadcastQueueUpdates,
})

local function resolveModeId(modeId)
	if typeof(modeId) == "string" and MatchmakingConfig.MODES[modeId] then
		return modeId
	end
	return MatchmakingService.getRecommendedModeId()
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	local resolvedMode = resolveModeId(modeId)
	if not resolvedMode then
		return
	end
	MatchmakingService.joinQueue(player, resolvedMode)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	sendQueueClear(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	MatchmakingService.joinQueue(player, MatchmakingService.getRecommendedModeId())
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onArenaFreed()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
