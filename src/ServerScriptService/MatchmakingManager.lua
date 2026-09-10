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

local initialized = false

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local MatchmakingManager = {}

function MatchmakingManager.init()
	if initialized then
		return
	end
	initialized = true

	MatchmakingService.configure({
		modes = MatchmakingConfig.MODES,
		getModeConfig = function(modeId)
			return MatchmakingConfig.MODES[modeId]
		end,
		notifyPlayer = function(player, payload)
			if player.Parent then
				QueueUpdate:FireClient(player, payload)
			end
		end,
		onJoinQueue = function(player)
			if HubService.setPhase then
				HubService.setPhase(player, "queue")
			end
		end,
		onLeaveQueue = function(player)
			if HubService.setPhase then
				HubService.setPhase(player, "hub")
			end
		end,
		onMatchReady = function(player)
			if HubService.leaveHubForArena then
				HubService.leaveHubForArena(player)
			end
		end,
		startMatch = function(playerList, modeId)
			MatchReady:Fire(playerList, modeId)
		end,
	})

	MatchmakingService.setArenaBusy(false)

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
			modeId = getRecommendedModeId()
		end

		if HubService.getPhase(player) == "arena" then
			return
		end

		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.setArenaBusy(false)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveAllQueues(player)
	end)

	print("[MatchmakingManager] Queue system ready")
end

function MatchmakingManager.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingManager.joinRecommendedQueue(player)
	return MatchmakingService.joinQueue(player, getRecommendedModeId())
end

function MatchmakingManager.joinQueue(player, modeId)
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingManager.leaveQueue(player)
	return MatchmakingService.leaveQueue(player)
end

function MatchmakingManager.setArenaBusy(busy)
	MatchmakingService.setArenaBusy(busy)
end

return MatchmakingManager