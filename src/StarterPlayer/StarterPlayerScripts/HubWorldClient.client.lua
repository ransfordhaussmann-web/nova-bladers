local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(0, 420, 0, 48)
hintLabel.Position = UDim2.new(0.5, -210, 0.85, 0)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 20
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local currentZone = nil
local inHub = false

local function getHubZones()
	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if not hub then return nil end
	local zones = hub:FindFirstChild("Zones")
	return zones
end

local function findNearestZone()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local zones = getHubZones()
	if not zones then return nil end

	local nearest = nil
	local nearestDist = HubConfig.ZONE_HINT_RANGE

	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			local dist = (zonePart.Position - root.Position).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearest = zonePart
			end
		end
	end

	return nearest
end

local function updateHint()
	if not inHub then
		hintGui.Enabled = false
		currentZone = nil
		return
	end

	local zone = findNearestZone()
	if zone then
		local zoneId = zone:GetAttribute("ZoneId")
		local hint = "Drücke E"
		for _, config in HubConfig.ZONES do
			if config.id == zoneId then
				hint = config.hint
				break
			end
		end
		hintLabel.Text = hint
		hintGui.Enabled = true
		if currentZone ~= zone then
			currentZone = zone
			Remotes.HubZoneHint:FireServer(zoneId)
		end
	else
		hintGui.Enabled = false
		currentZone = nil
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	if not inHub then
		hintGui.Enabled = false
		currentZone = nil
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub or not currentZone then return end
	if input.KeyCode ~= HubConfig.INTERACT_KEY then return end

	local action = currentZone:GetAttribute("ZoneAction")
	if typeof(action) == "string" then
		Remotes.HubZoneAction:FireServer(action)
	end
end)

task.spawn(function()
	while true do
		updateHint()
		task.wait(0.25)
	end
end)
