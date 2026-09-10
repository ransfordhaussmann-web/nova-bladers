local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(ReplicatedStorage.NovaBladers.MatchmakingService)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local function sendQueueUpdate(player, snapshot)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, snapshot)
	end
end

local function resolveModeId(modeId)
	if typeof(modeId) == "string" and MatchmakingConfig.MODES[modeId] then
		return modeId
	end
	return MatchmakingConfig.DEFAULT_MODE
end

MatchmakingService.register({
	onQueueUpdate = sendQueueUpdate,
	onMatchReady = function(matchPlayers, modeId)
		for _, player in matchPlayers do
			HubService.enterArena(player, modeId)
		end
		Bindables.MatchReady:Fire(matchPlayers, modeId)
	end,
	onPlayerLeftQueue = function(player)
		-- phase reset handled by HubService.leaveQueue
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end
	HubService.enterQueue(player, resolveModeId(modeId))
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	HubService.leaveQueue(player)
end)

Bindables.MatchStarted.Event:Connect(function()
	MatchmakingService.setArenaBusy(true)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
