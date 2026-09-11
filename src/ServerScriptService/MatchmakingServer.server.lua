local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function leaveHubForMatch(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	HubService.enterArena(player)
end

MatchmakingService.register({
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
	onMatchReady = function(players, modeId)
		for _, player in players do
			leaveHubForMatch(player)
		end
		Bindables.MatchReady:Fire(players, modeId)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.isValidMode(modeId) then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end
	if typeof(modeId) == "string" and MatchmakingConfig.isValidMode(modeId) then
		MatchmakingService.joinQueue(player, modeId)
		return
	end
	local count = #Players:GetPlayers()
	local fallback = "training"
	if count >= 3 then
		fallback = "ffa"
	elseif count == 2 then
		fallback = "pvp"
	end
	MatchmakingService.joinQueue(player, fallback)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

print("[MatchmakingServer] Queue ready — Training / PvP / FFA")
