local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingBridge = require(ReplicatedStorage.NovaBladers.MatchmakingBridge)
local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local arenaBusy = false

local function getRecommendedModeId(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

local function setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		MatchmakingService.onArenaFreed()
	end
end

MatchmakingService.configure({
	isArenaBusy = function()
		return arenaBusy
	end,
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
	onMatchReady = function(playerList, modeId)
		setArenaBusy(true)
		Bindables.MatchReady:Fire(playerList, modeId)
	end,
})

MatchmakingBridge.register({
	joinQueue = function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end,
	leaveQueue = function(player)
		MatchmakingService.leaveQueue(player)
	end,
	getRecommendedModeId = getRecommendedModeId,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getRecommendedModeId(#Players:GetPlayers())
	end
	if not MatchmakingConfig.MODES[modeId] then
		modeId = getRecommendedModeId(#Players:GetPlayers())
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
