local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local function sendIdle(player)
	QueueUpdate:FireClient(player, {
		inQueue = false,
		status = "idle",
		modeId = nil,
		modeLabel = "",
		queued = 0,
		minPlayers = 0,
		maxPlayers = 0,
	})
end

MatchmakingService.register({
	onJoinQueue = function(player, modeId)
		HubService.setQueuePhase(player, modeId, "queued")
	end,
	onLeaveQueue = function(player)
		HubService.setQueuePhase(player, nil, "hub")
		sendIdle(player)
	end,
	onQueueUpdate = function(player, payload)
		if payload.status == "pending" then
			HubService.setQueuePhase(player, payload.modeId, "pending")
		end
		QueueUpdate:FireClient(player, payload)
	end,
	onMatchReady = function(modeId, players)
		for _, queuedPlayer in players do
			HubService.setQueuePhase(queuedPlayer, modeId, "arena")
		end
		MatchReady:Fire(modeId, players)
	end,
})

QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end
	if modeId == nil or modeId == "" then
		modeId = MatchmakingService.resolveQuickMatchMode()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.clearPlayer(player)
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
