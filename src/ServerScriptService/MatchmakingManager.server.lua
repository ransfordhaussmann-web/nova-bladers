local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if MatchmakingService.getPlayerMode(player) then
			QueueUpdate:FireClient(player, MatchmakingService.buildPlayerUpdate(player))
		end
	end
end

QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local ok, result = MatchmakingService.joinQueue(player, modeId)
	if ok then
		QueueUpdate:FireClient(player, result)
	else
		QueueUpdate:FireClient(player, { inQueue = false, error = result })
	end
end)

QueueLeave.OnServerEvent:Connect(function(player)
	local ok, update = MatchmakingService.leaveQueue(player)
	if ok then
		QueueUpdate:FireClient(player, { inQueue = false })
	end
end)

MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	if MatchmakingService.getPlayerMode(player) then
		MatchmakingService.leaveQueue(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		broadcastQueueUpdates()
	end
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
