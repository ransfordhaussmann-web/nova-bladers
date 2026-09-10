local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function broadcastQueueUpdates()
	local snapshots = MatchmakingService.getAllSnapshots()
	for _, player in Players:GetPlayers() do
		local personal = MatchmakingService.getPlayerQueue(player)
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = personal ~= nil,
			queue = personal,
			snapshots = snapshots,
		})
	end
end

MatchmakingService.setOnQueueChanged(broadcastQueueUpdates)

MatchmakingService.setOnMatchReady(function(matchedPlayers, modeId)
	for _, player in matchedPlayers do
		if HubService.getPhase(player) ~= "arena" then
			HubService.prepareForArena(player)
		end
	end
	Bindables.MatchReady:Fire(matchedPlayers, modeId)
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end
	local ok, reason = MatchmakingService.joinQueue(player, modeId)
	if not ok and reason == "queue_full" then
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			error = "queue_full",
			queue = MatchmakingService.getPlayerQueue(player),
			snapshots = MatchmakingService.getAllSnapshots(),
		})
	end
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchStarted.Event:Connect(function()
	MatchmakingService.setArenaBusy(true)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
	for modeId in require(ReplicatedStorage.NovaBladers.MatchmakingConfig).MODES do
		MatchmakingService.tryStartMatch(modeId)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
