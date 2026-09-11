local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchmakingManager = require(script.Parent.MatchmakingManager)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingManager.init({
	onMatchReady = function(matchPlayers, modeId)
		Bindables.MatchReady:Fire(matchPlayers, modeId)
	end,
	onPlayersEnterArena = function(matchPlayers)
		for _, player in matchPlayers do
			HubService.enterArena(player)
		end
	end,
	broadcastUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
})

local function joinQueue(player, modeId)
	local success, status = MatchmakingManager.joinQueue(player, modeId)
	if success then
		HubService.enterQueue(player)
	else
		Remotes.QueueUpdate:FireClient(player, {
			error = status,
		})
	end
end

local function leaveQueue(player)
	MatchmakingManager.leaveQueue(player)
	HubService.leaveQueue(player)
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.getModeFromPlayerCount(#Players:GetPlayers())
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingManager.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingManager.onPlayerRemoving(player)
end)

local function hookHubInteractions()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		warn("[MatchmakingManager] Hub not found — portal/mode-pad queue hooks skipped")
		return
	end

	local portal = hub:FindFirstChild("ArenaPortal")
	if portal then
		local prompt = portal:FindFirstChild("EnterArenaPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.ActionText = "Warteschlange"
			prompt.Triggered:Connect(function(player)
				local modeId = MatchmakingConfig.getModeFromPlayerCount(#Players:GetPlayers())
				joinQueue(player, modeId)
			end)
		end
	end

	for _, child in hub:GetChildren() do
		if child.Name:match("^ModePad_") then
			local modeId = child.Name:gsub("^ModePad_", "")
			if MatchmakingConfig.getMode(modeId) then
				local prompt = child:FindFirstChild("QueuePrompt")
				if not prompt then
					prompt = Instance.new("ProximityPrompt")
					prompt.Name = "QueuePrompt"
					prompt.ActionText = "Queue"
					prompt.ObjectText = MatchmakingConfig.getMode(modeId).label
					prompt.KeyboardKeyCode = Enum.KeyCode.E
					prompt.HoldDuration = 0
					prompt.MaxActivationDistance = 10
					prompt.RequiresLineOfSight = false
					prompt.Parent = child
				end
				prompt.Triggered:Connect(function(player)
					joinQueue(player, modeId)
				end)
			end
		end
	end
end

task.defer(hookHubInteractions)

print("[MatchmakingManager] Queue system ready")
