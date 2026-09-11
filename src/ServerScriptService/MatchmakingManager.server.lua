local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchState = require(script.Parent.MatchState)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local service = MatchmakingService.new({
	isArenaBusy = function()
		return MatchState.isBusy()
	end,
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
	onMatchReady = function(payload)
		for _, player in payload.players do
			HubService.leaveHubForArena(player)
		end
		Bindables.MatchReady:Fire(payload)
	end,
})

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= MatchmakingConfig.MODES.ffa.minPlayers then
		return "ffa"
	elseif count >= MatchmakingConfig.MODES.pvp.minPlayers then
		return "pvp"
	end
	return "training"
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
		modeId = getRecommendedModeId()
	end
	service:joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	service:leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	service:onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	service:onPlayerRemoving(player)
end)

local lastTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastTick >= MatchmakingConfig.QUEUE_TICK then
		lastTick = now
		service:tick()
	end
end)

HubService.registerMatchmaking({
	joinQueue = function(player, modeId)
		if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
			modeId = getRecommendedModeId()
		end
		service:joinQueue(player, modeId)
	end,
	getRecommendedModeId = getRecommendedModeId,
})

print("[MatchmakingManager] Queue system ready")
