local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchCoordinator = require(script.Parent.MatchCoordinator)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init(Remotes)
MatchCoordinator.init(Remotes, Bindables)

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function resolveModeId(modeId)
	if typeof(modeId) == "string" and MatchmakingConfig.MODES[modeId] then
		return modeId
	end
	return getRecommendedModeId()
end

local function joinQueue(player, modeId)
	local resolved = resolveModeId(modeId)
	local ok = MatchmakingService.joinQueue(player, resolved)
	if ok then
		MatchCoordinator.onQueueChanged(resolved)
	end
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue ready — portal, mode pads, and lobby button join matchmaking")
