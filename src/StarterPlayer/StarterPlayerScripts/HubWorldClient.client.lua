local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

local currentZone = nil
local hintGui

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -80)
	frame.Size = UDim2.new(0, 420, 0, 56)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamMedium
	label.Parent = frame

	hintGui = screen
	return screen
end

local function getZoneConfig(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

local function setZoneHint(zoneId)
	local zone = zoneId and getZoneConfig(zoneId)
	currentZone = zone

	local gui = ensureHintGui()
	if not zone then
		gui.Enabled = false
		return
	end

	gui.Panel.HintLabel.Text = zone.hint
	gui.Enabled = true
end

local function getNearestZone()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return nil end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return nil end

	local nearestId
	local nearestDist = math.huge

	for _, part in zones:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("ZoneId") then
			local dist = (part.Position - root.Position).Magnitude
			local reach = math.max(part.Size.X, part.Size.Z) / 2 + 2
			if dist <= reach and dist < nearestDist then
				nearestDist = dist
				nearestId = part:GetAttribute("ZoneId")
			end
		end
	end

	return nearestId
end

local function tryZoneAction()
	if not currentZone or currentZone.action == "none" then return end
	Remotes.HubZoneAction:FireServer(currentZone.action)
	if currentZone.action == "open_bey_select" then
		local select = player.PlayerGui:FindFirstChild("BeySelect")
		if select then select.Enabled = true end
	end
end

task.spawn(function()
	while true do
		setZoneHint(getNearestZone())
		task.wait(0.25)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = true end
end)
