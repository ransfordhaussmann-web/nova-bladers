local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function broadcastQueueUpdate(player, payload)
	Remotes.QueueUpdate:FireClient(player, payload)
end

MatchmakingService.setBroadcast(broadcastQueueUpdate)

MatchmakingService.setMatchReadyHandler(function(payload)
	for _, player in payload.players do
		HubService.leaveHubForArena(player)
	end
	Bindables.MatchReady:Fire(payload)
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

local function joinRecommendedQueue(player)
	local modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
	MatchmakingService.joinQueue(player, modeId)
end

local function wireHubInteractions()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		warn("[MatchmakingManager] Hub not found — pad/portal queue wiring skipped")
		return
	end

	for _, child in hub:GetChildren() do
		local modeId = child.Name:match("^ModePad_(.+)$")
		if modeId then
			local prompt = child:FindFirstChild("QueuePrompt")
			if prompt then
				prompt.Triggered:Connect(function(player)
					MatchmakingService.joinQueue(player, modeId)
				end)
			end
		end
	end

	local portal = hub:FindFirstChild("ArenaPortal")
	if portal then
		local portalPrompt = portal:FindFirstChild("EnterArenaPrompt")
		if portalPrompt then
			portalPrompt.Triggered:Connect(function(player)
				joinRecommendedQueue(player)
			end)
		end
	end
end

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

Remotes.ReturnToHub.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

task.defer(wireHubInteractions)

print("[MatchmakingManager] Matchmaking queue ready")
