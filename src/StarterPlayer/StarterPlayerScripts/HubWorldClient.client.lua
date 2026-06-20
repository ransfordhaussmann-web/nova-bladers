local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
hintLabel.Size = UDim2.fromOffset(360, 44)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 18
hintLabel.Text = ""
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local activeZoneId = nil

local function getCharacterRoot()
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function getNearestZone()
	local root = getCharacterRoot()
	if not root then
		return nil
	end

	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	local zones = hub and hub:FindFirstChild("Zones")
	if not zones then
		return nil
	end

	local nearestZone = nil
	local nearestDistance = HubConfig.INTERACT_DISTANCE

	for _, marker in zones:GetChildren() do
		if marker:IsA("BasePart") then
			local distance = (marker.Position - root.Position).Magnitude
			if distance <= nearestDistance then
				nearestDistance = distance
				nearestZone = marker
			end
		end
	end

	return nearestZone
end

local function updateHint()
	if player:GetAttribute("InHub") == false then
		hintGui.Enabled = false
		activeZoneId = nil
		return
	end

	local zonePart = getNearestZone()
	if not zonePart then
		hintGui.Enabled = false
		activeZoneId = nil
		return
	end

	activeZoneId = zonePart:GetAttribute("ZoneId")
	local zoneName = zonePart.Name
	for _, zone in HubConfig.ZONES do
		if zone.id == activeZoneId then
			zoneName = zone.name
			break
		end
	end

	hintLabel.Text = string.format("[E] %s", zoneName)
	hintGui.Enabled = true
end

game:GetService("RunService").Heartbeat:Connect(updateHint)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not activeZoneId then
		return
	end
	if player:GetAttribute("InHub") == false then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		remotes.HubZoneAction:FireServer(activeZoneId)
	end
end)

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
