local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()

local function preparePlayersForMatch(playerList)
	for _, player in playerList do
		HubService.prepareForMatch(player)
	end
end

MatchmakingService.init(Remotes, Bindables, preparePlayersForMatch)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getSuggestedMode()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

local function connectModePad(padPart, modeId)
	local prompt = padPart:FindFirstChild("JoinQueuePrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		MatchmakingService.joinQueue(player, modeId)
	end)
end

local function wireHubInteractions()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		warn("[MatchmakingManager] Hub not found — mode pads unavailable")
		return
	end

	for modeKey, padConfig in HubConfig.MODE_PADS do
		local pad = hub:FindFirstChild("ModePad_" .. padConfig.id)
		if pad then
			connectModePad(pad, padConfig.id)
		end
	end

	local portal = hub:FindFirstChild("ArenaPortal")
	if portal then
		local portalPrompt = portal:FindFirstChild("EnterArenaPrompt")
		if portalPrompt then
			portalPrompt.ActionText = "Warteschlange"
			portalPrompt.ObjectText = "Nova Arena"
		end
	end
end

task.defer(wireHubInteractions)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Matchmaking queue ready")
