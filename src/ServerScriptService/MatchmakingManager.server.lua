local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)

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

MatchmakingService.setBroadcastHandler(function(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end)

MatchmakingService.onMatchReady = function(players, modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	if not mode then
		return
	end

	task.delay(mode.startDelay, function()
		local ready = {}
		for _, player in players do
			if player.Parent and HubService.getPhase(player) == "hub" then
				table.insert(ready, player)
			end
		end

		if #ready < mode.minPlayers then
			for _, player in ready do
				MatchmakingService.joinQueue(player, modeId)
			end
			return
		end

		for _, player in ready do
			HubService.leaveHubForArena(player)
			Remotes.QueueUpdate:FireClient(player, {
				status = "matched",
				modeId = modeId,
			})
		end

		Bindables.MatchReady:Fire(ready, modeId)
	end)
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or modeId == "auto" then
		modeId = getDefaultModeId()
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
