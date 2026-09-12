local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingManager = {}
local initialized = false

function MatchmakingManager.init()
	if initialized then
		return
	end
	initialized = true

	local Remotes, Bindables = RemotesSetup.ensure()

	local function leaveHubForMatch(player)
		if HubService.getPhase(player) == "arena" then
			return
		end
		HubService.enterArena(player)
	end

	MatchmakingService.registerHandlers({
		onMatchReady = function(players, modeId)
			for _, player in players do
				if player.Parent then
					leaveHubForMatch(player)
					Remotes.QueueUpdate:FireClient(player, {
						status = "matched",
						modeId = modeId,
						modeLabel = MatchmakingConfig.getMode(modeId).label,
					})
				end
			end
			Bindables.MatchReady:Fire(players, modeId)
		end,
		onQueueUpdate = function(player, payload)
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end,
	})

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingManager.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.setArenaBusy(false)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	print("[MatchmakingManager] Queue system ready")
end

function MatchmakingManager.joinQueue(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingManager.joinRecommendedQueue(player)
	local modeId = MatchmakingService.getRecommendedMode(#Players:GetPlayers())
	MatchmakingManager.joinQueue(player, modeId)
end

function MatchmakingManager.leaveQueue(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingManager.markArenaBusy()
	MatchmakingService.setArenaBusy(true)
end

return MatchmakingManager
