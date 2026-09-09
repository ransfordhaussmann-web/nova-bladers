local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local MatchmakingInit = {}
local initialized = false

local function getActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingInit.init()
	if initialized then
		return
	end
	initialized = true

	local Remotes, Bindables = RemotesSetup.ensure()

	MatchmakingService.register({
		onQueueUpdate = function(player, payload)
			Remotes.QueueUpdate:FireClient(player, payload)
		end,
		onMatchReady = function(playerList, _modeId)
			for _, player in playerList do
				HubService.leaveHubForArena(player)
			end
			Bindables.MatchReady:Fire(playerList, _modeId)
		end,
	})

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
			modeId = getActiveModeId()
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

	print("[MatchmakingInit] Queue system ready")
end

return MatchmakingInit
