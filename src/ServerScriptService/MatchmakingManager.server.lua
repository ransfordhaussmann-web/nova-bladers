local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueToMembers(modeId, payload)
	local mode = MatchmakingConfig.MODES[modeId]
	if not mode then
		return
	end

	for _, player in Players:GetPlayers() do
		if MatchmakingService.getPlayerMode(player) == modeId then
			sendQueueUpdate(player, payload)
		end
	end
end

MatchmakingService.setCallbacks({
	onMatchReady = function(players, modeId)
		for _, player in players do
			HubService.leaveHubForArena(player)
		end
		Bindables.MatchReady:Fire(players, modeId)
	end,
	onQueueUpdate = function(modeId, payload)
		broadcastQueueToMembers(modeId, payload)
	end,
})

local function joinQueue(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if MatchmakingService.joinQueue(player, modeId) then
		sendQueueUpdate(player, MatchmakingService.getQueuePayload(modeId))
	end
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	sendQueueUpdate(player, { status = "left" })
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.removePlayer(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

print("[MatchmakingManager] Queue system ready")
