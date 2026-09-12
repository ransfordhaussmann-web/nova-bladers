local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchmakingBridge = require(ReplicatedStorage.NovaBladers.MatchmakingBridge)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local function fireQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

MatchmakingService.init({
	onMatchReady = function(modeId, playerList)
		for _, player in playerList do
			fireQueueUpdate(player, {
				status = "starting",
				queue = { modeId = modeId },
			})
		end
		MatchReady:Fire(modeId, playerList)
	end,
	onQueueUpdate = function(player, payload)
		fireQueueUpdate(player, payload)
	end,
})

MatchmakingBridge.register({
	joinQueue = function(player, modeId)
		return MatchmakingService.joinQueue(player, modeId)
	end,
	leaveQueue = function(player)
		return MatchmakingService.leaveQueue(player)
	end,
	getPlayerQueue = function(player)
		return MatchmakingService.getPlayerQueue(player)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.removePlayer(player)
end)

print("[MatchmakingManager] Queue system ready")
