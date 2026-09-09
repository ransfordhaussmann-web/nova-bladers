local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local function getDefaultModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

MatchmakingService.setCallbacks({
	onMatchReady = function(matchPlayers, modeId)
		for _, player in matchPlayers do
			HubService.prepareForMatch(player)
		end
		MatchReady:Fire(matchPlayers, modeId)
	end,
	onQueueChanged = function(player, payload)
		if player.Parent then
			QueueUpdate:FireClient(player, payload)
		end
	end,
})

QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or modeId == "" then
		modeId = getDefaultModeId()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		MatchmakingService.tickQueueUpdates()
	end
end)

print("[MatchmakingManager] Queue system ready")
