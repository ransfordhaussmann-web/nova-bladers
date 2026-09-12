local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchmakingBridge = require(script.Parent.MatchmakingBridge)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local service = MatchmakingService.new()

service.onQueueUpdate = function(player, payload)
	if player.Parent then
		QueueUpdate:FireClient(player, payload)
	end
end

service.onMatchReady = function(players, modeId)
	MatchReady:Fire(players, modeId)
end

MatchmakingBridge.register({
	joinQueue = function(player, modeId)
		return service:joinQueue(player, modeId)
	end,
	leaveQueue = function(player)
		service:leaveQueue(player)
	end,
	getQueueState = function(player)
		return service:getPlayerPayload(player)
	end,
	setArenaBusy = function(busy)
		service:setArenaBusy(busy)
	end,
})

QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = nil
	end
	service:joinQueue(player, modeId or "pvp")
end)

QueueLeave.OnServerEvent:Connect(function(player)
	service:leaveQueue(player)
end)

MatchEnded.Event:Connect(function()
	service:setArenaBusy(false)
	for modeId in service.queues do
		service:_tryStartMatch(modeId, modeId == "ffa")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	service:onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
