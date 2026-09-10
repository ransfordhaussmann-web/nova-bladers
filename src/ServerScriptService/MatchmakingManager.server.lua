local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function sendQueueUpdate(player, payload)
	Remotes.QueueUpdate:FireClient(player, payload)
end

MatchmakingService.register({
	onQueueUpdate = sendQueueUpdate,
	onMatchReady = function(match)
		for _, player in match.players do
			if HubService.setPhase then
				HubService.setPhase(player, "arena")
			end
		end
		Bindables.MatchReady:Fire(match)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end

	local ok = MatchmakingService.joinQueue(player, modeId)
	if ok and HubService.setPhase then
		HubService.setPhase(player, "queue")
	end
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	if HubService.setPhase then
		HubService.setPhase(player, "hub")
	end
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

local lastTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastTick < MatchmakingConfig.QUEUE_UPDATE_INTERVAL then
		return
	end
	lastTick = now
	MatchmakingService.processQueues()
end)

print("[MatchmakingManager] Queue system ready")
