local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local function fireQueueUpdate(player, payload)
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function broadcastQueueUpdate(modeId, payload, queuePlayers)
	for _, player in queuePlayers do
		if player.Parent then
			fireQueueUpdate(player, payload)
		end
	end
end

local function notifyPlayerQueueLeft(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

MatchmakingService.register({
	onQueueUpdate = broadcastQueueUpdate,
	onMatchReady = function(modeId, players)
		for _, player in players do
			if HubService.prepareForMatch then
				HubService.prepareForMatch(player)
			end
		end
		Bindables.MatchReady:Fire(modeId, players)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	local ok, reason = MatchmakingService.joinQueue(player, modeId)
	if not ok and reason == "queue_full" then
		fireQueueUpdate(player, { status = "error", message = "Warteschlange voll" })
	end
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	notifyPlayerQueueLeft(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.clearPlayer(player)
end)

local lastTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastTick >= MatchmakingConfig.QUEUE_UPDATE_INTERVAL then
		lastTick = now
		MatchmakingService.tick()
	end
end)

print("[MatchmakingManager] Queue system ready")
