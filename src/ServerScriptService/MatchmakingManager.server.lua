local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function onQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function onMatchReady(matchPlayers, modeId)
	for _, player in matchPlayers do
		if HubService.prepareForMatch then
			HubService.prepareForMatch(player)
		end
	end

	Bindables.MatchReady:Fire(matchPlayers, modeId)
end

MatchmakingService.registerHandlers({
	onQueueUpdate = onQueueUpdate,
	onMatchReady = onMatchReady,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getPreferredModeForPlayerCount(#Players:GetPlayers())
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.removeFromQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	local modeId = MatchmakingService.getPreferredModeForPlayerCount(#Players:GetPlayers())
	MatchmakingService.joinQueue(player, modeId)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchStateService.setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

local function connectModePadPrompts()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		return
	end

	for _, child in hub:GetChildren() do
		local modeId = child.Name:match("^ModePad_(.+)$")
		if modeId then
			local prompt = child:FindFirstChild("JoinQueuePrompt")
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
			portalPrompt.ActionText = "Warteschlange"
			portalPrompt.Triggered:Connect(function(player)
				local modeId = MatchmakingService.getPreferredModeForPlayerCount(#Players:GetPlayers())
				MatchmakingService.joinQueue(player, modeId)
			end)
		end
	end
end

task.defer(connectModePadPrompts)

print("[MatchmakingManager] Queue system ready")
