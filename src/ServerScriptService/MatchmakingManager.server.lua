local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init({
	remotes = Remotes,
	onMatchReady = function(players, modeId)
		for _, player in players do
			HubService.leaveHubForArena(player)
		end
		Bindables.MatchReady:Fire(players, modeId)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.getSuggestedMode(#Players:GetPlayers())
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	local ok, reason = MatchmakingService.joinQueue(player, modeId)
	if not ok then
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			status = "error",
			error = reason,
		})
	end
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
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

print("[MatchmakingManager] Queue system ready")
