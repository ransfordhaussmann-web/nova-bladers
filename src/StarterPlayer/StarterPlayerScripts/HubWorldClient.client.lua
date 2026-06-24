local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local player = Players.LocalPlayer
local HINT_RANGE = HubConfig.PROXIMITY_DISTANCE + 4

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
hintLabel.Size = UDim2.fromOffset(360, 40)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.25
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextSize = 16
hintLabel.Parent = hintGui

local currentZoneId

local function getHubZones()
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if not hub then
		return {}
	end
	local zones = hub:FindFirstChild("Zones")
	if not zones then
		return {}
	end
	return zones:GetChildren()
end

local function findNearestZone(rootPart)
	local nearest
	local nearestDist = HINT_RANGE

	for _, zonePart in getHubZones() do
		if zonePart:IsA("BasePart") then
			local dist = (zonePart.Position - rootPart.Position).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearest = zonePart
			end
		end
	end

	return nearest
end

local function showHint(text)
	hintLabel.Text = text
	hintGui.Enabled = true
end

local function hideHint()
	hintGui.Enabled = false
	currentZoneId = nil
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload and payload.text then
		showHint(payload.text)
		task.delay(3, function()
			if hintLabel.Text == payload.text then
				hideHint()
			end
		end)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	if not character then
		hideHint()
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		hideHint()
		return
	end

	local zonePart = findNearestZone(root)
	if not zonePart then
		hideHint()
		return
	end

	local zoneId = zonePart:GetAttribute("ZoneId")
	if zoneId == currentZoneId then
		return
	end
	currentZoneId = zoneId

	local zoneConfig = HubConfig.ZONES[zoneId]
	if zoneConfig then
		showHint(zoneConfig.hint)
	end
end)
