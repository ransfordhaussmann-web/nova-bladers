local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()
MatchmakingService.init(Remotes, Bindables)

local function connectModePads()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		return
	end

	for _, padConfig in pairs(HubConfig.MODE_PADS) do
		local pad = hub:FindFirstChild("ModePad_" .. padConfig.id)
		if not pad then
			continue
		end

		local prompt = pad:FindFirstChild("QueuePrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "QueuePrompt"
			prompt.ActionText = "Queue beitreten"
			prompt.ObjectText = padConfig.label
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = pad
		end

		prompt.Triggered:Connect(function(player)
			MatchmakingService.joinQueue(player, padConfig.id)
		end)
	end
end

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

task.defer(connectModePads)

print("[MatchmakingManager] Queue system ready")
