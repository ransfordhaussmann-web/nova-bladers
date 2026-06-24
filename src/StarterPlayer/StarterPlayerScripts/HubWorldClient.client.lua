local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = NovaBladers:WaitForChild("Remotes")

local currentZoneId = nil
local zonesFolder = nil

local gui = Instance.new("ScreenGui")
gui.Name = "HubWorldUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "ZoneHint"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -80)
hintFrame.Size = UDim2.fromOffset(360, 44)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
hintFrame.BackgroundTransparency = 0.2
hintFrame.Visible = false
hintFrame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.fromScale(1, 1)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextSize = 16
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local function getZoneConfig(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

local function isInsideZone(zonePart, position)
	local relative = zonePart.CFrame:PointToObjectSpace(position)
	local half = zonePart.Size * 0.5
	return math.abs(relative.X) <= half.X
		and math.abs(relative.Y) <= half.Y
		and math.abs(relative.Z) <= half.Z
end

local function detectZone()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not zonesFolder then
		return nil
	end

	for _, zonePart in zonesFolder:GetChildren() do
		if zonePart:IsA("BasePart") and isInsideZone(zonePart, hrp.Position) then
			return zonePart:GetAttribute("ZoneId")
		end
	end
	return nil
end

local function setHint(zoneId)
	if zoneId == currentZoneId then
		return
	end
	currentZoneId = zoneId

	if zoneId then
		local zone = getZoneConfig(zoneId)
		hintLabel.Text = zone and zone.hint or zoneId
		hintFrame.Visible = true
	else
		hintFrame.Visible = false
	end
end

local function onInteract()
	if not currentZoneId then return end
	local zone = getZoneConfig(currentZoneId)
	if not zone or zone.action == "none" then return end
	remotes.HubZoneAction:FireServer(currentZoneId)
end

task.spawn(function()
	local hub = workspace:WaitForChild(HubConfig.HUB_FOLDER, 30)
	if not hub then return end
	zonesFolder = hub:WaitForChild("Zones", 10)
end)

RunService.Heartbeat:Connect(function()
	setHint(detectZone())
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		onInteract()
	end
end)
