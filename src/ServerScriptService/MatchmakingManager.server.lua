local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingBridge = require(ReplicatedStorage.NovaBladers.MatchmakingBridge)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function getDefaultModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function preparePlayersForMatch(players)
	for _, player in players do
		HubService.prepareForArena(player)
	end
end

MatchmakingService.init(Remotes, function(players, modeId)
	preparePlayersForMatch(players)
	Bindables.MatchReady:Fire(players, modeId)
end)

MatchmakingBridge.register({
	joinQueue = function(player, modeId)
		return MatchmakingService.joinQueue(player, modeId)
	end,
	leaveQueue = function(player)
		MatchmakingService.leaveQueue(player)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
		modeId = getDefaultModeId()
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
