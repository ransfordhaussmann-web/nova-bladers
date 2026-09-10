local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init(Remotes, Bindables)

local function getSuggestedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function joinQueue(player, modeId)
	local ok = MatchmakingService.joinQueue(player, modeId)
	if ok then
		HubService.enterArena(player)
	end
	return ok
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getSuggestedModeId()
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	HubService.returnPlayerToHub(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	joinQueue(player, getSuggestedModeId())
end)

Bindables.MatchStarted.Event:Connect(function()
	MatchmakingService.onMatchStarted()
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

local function connectHubPads()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		return
	end

	local portal = hub:FindFirstChild("ArenaPortal")
	if portal then
		local prompt = portal:FindFirstChild("EnterArenaPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.ActionText = "Warteschlange"
			prompt.Triggered:Connect(function(player)
				joinQueue(player, getSuggestedModeId())
			end)
		end
	end

	for modeKey, padConfig in HubConfig.MODE_PADS do
		local pad = hub:FindFirstChild("ModePad_" .. padConfig.id)
		if not pad then
			continue
		end
		local prompt = pad:FindFirstChild("QueuePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				joinQueue(player, padConfig.id)
			end)
		end
	end
end

task.defer(connectHubPads)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
