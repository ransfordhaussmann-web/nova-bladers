local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function sendQueueUpdate(player)
	Remotes.QueueUpdate:FireClient(player, MatchmakingService.buildStatus(player))
end

MatchmakingService.registerHandlers({
	onQueueUpdate = sendQueueUpdate,
	onMatchReady = function(payload)
		for _, player in payload.players do
			if HubService.getPhase(player) ~= "arena" then
				HubService.leaveHubForArena(player)
			end
		end
		Bindables.MatchReady:Fire(payload)
	end,
})

local function joinQueue(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getRecommendedMode()
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

local function wireHubEntry(entry, modeId)
	if not entry then
		return
	end
	entry.Triggered:Connect(function(player)
		joinQueue(player, modeId)
	end)
end

local function wireRecommendedEntry(entry)
	if not entry then
		return
	end
	entry.Triggered:Connect(function(player)
		joinQueue(player, MatchmakingService.getRecommendedMode())
	end)
end

task.defer(function()
	local hubFolder = workspace:WaitForChild("Hub", 30)
	if not hubFolder then
		return
	end

	for modeId in MatchmakingConfig.MODES do
		local pad = hubFolder:FindFirstChild("ModePad_" .. modeId)
		if pad then
			local prompt = pad:FindFirstChild("JoinQueuePrompt")
			if prompt then
				wireHubEntry(prompt, modeId)
			end
		end
	end

	local portal = hubFolder:FindFirstChild("ArenaPortal")
	if portal then
		local portalPrompt = portal:FindFirstChild("EnterArenaPrompt")
		if portalPrompt then
			portalPrompt.ActionText = "Warteschlange"
			portalPrompt.ObjectText = "Nova Arena"
			wireRecommendedEntry(portalPrompt)
		end
	end
end)

print("[MatchmakingManager] Queue ready — Mode-Pads, Portal, Lobby-Button")
