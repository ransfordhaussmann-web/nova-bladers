local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local inHub = true

local function setCharacterInHub(enabled)
	inHub = enabled
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = enabled and 16 or 0
	end
end

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	setCharacterInHub(true)
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" and payload.inHub ~= nil then
		inHub = payload.inHub
		setCharacterInHub(inHub)
	end
end)

player.CharacterAdded:Connect(function()
	task.defer(function()
		setCharacterInHub(inHub)
	end)
end)

-- Highlight hub portals for discoverability
task.spawn(function()
	local hub = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if not hub then
		return
	end

	local portals = hub:FindFirstChild("Portals")
	if not portals then
		return
	end

	for _, portal in portals:GetChildren() do
		if portal:IsA("BasePart") then
			local light = Instance.new("PointLight")
			light.Color = portal.Color
			light.Brightness = 1.2
			light.Range = 12
			light.Parent = portal
		end
	end
end)
