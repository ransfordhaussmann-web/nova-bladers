local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function onQueueJoin(player, modeId)
	if typeof(modeId) ~= "string" or modeId == "" or modeId == "auto" then
		modeId = MatchmakingService.resolveAutoMode()
	end

	local ok, reason = MatchmakingService.joinQueue(player, modeId)
	if not ok and reason == "queue_full" then
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			error = "queue_full",
			modeId = modeId,
		})
	end
end

MatchmakingService.registerHandlers({
	onQueueUpdate = function(player, payload)
		Remotes.QueueUpdate:FireClient(player, payload)
	end,
	onMatchReady = function(modeId, players)
		Bindables.MatchReady:Fire(modeId, players)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	onQueueJoin(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchStarted.Event:Connect(function()
	MatchmakingService.setArenaBusy(true)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

print("[MatchmakingManager] Queue system ready")
