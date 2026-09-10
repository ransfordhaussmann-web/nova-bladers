local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function onMatchReady(modeId, playerList)
	for _, player in playerList do
		HubService.setPlayerPhase(player, "arena")
	end
	Bindables.MatchReady:Fire(modeId, playerList)
end

MatchmakingService.init(Remotes, onMatchReady)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or modeId == "auto" then
		modeId = getRecommendedModeId()
	end

	local ok, err = MatchmakingService.joinQueue(player, modeId)
	if ok then
		HubService.setPlayerPhase(player, "queued")
	else
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			status = "error",
			error = err,
			inQueue = false,
		})
	end
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	if MatchmakingService.leaveQueue(player) then
		HubService.setPlayerPhase(player, "hub")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		for modeId in MatchmakingConfig.MODES do
			MatchmakingService.broadcastQueueUpdate(modeId)
		end
	end
end)

print("[MatchmakingManager] Queue system ready")
