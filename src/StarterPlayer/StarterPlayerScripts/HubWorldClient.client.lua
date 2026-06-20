local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubHint"
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
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 18
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local activeZoneId = nil
local inArena = false

local function getCharacterRoot()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function getZoneParts()
	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then return {} end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return {} end
	return zones:GetChildren()
end

local function findNearestZone()
	local root = getCharacterRoot()
	if not root then return nil end

	local nearestZone = nil
	local nearestDist = HubConfig.INTERACT_RANGE

	for _, part in getZoneParts() do
		if part:IsA("BasePart") then
			local dist = (part.Position - root.Position).Magnitude
			if dist <= nearestDist then
				nearestDist = dist
				nearestZone = part
			end
		end
	end

	return nearestZone
end

local function refreshHint()
	if inArena then
		hintGui.Enabled = false
		activeZoneId = nil
		return
	end

	local zonePart = findNearestZone()
	if zonePart then
		activeZoneId = zonePart:GetAttribute("ZoneId")
		hintLabel.Text = zonePart:GetAttribute("Hint") or "E — Interagieren"
		hintGui.Enabled = true
	else
		activeZoneId = nil
		hintGui.Enabled = false
	end
end

local function tryInteract()
	if inArena or not activeZoneId then return end
	remotes.HubZoneAction:FireServer(activeZoneId)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryInteract()
	end
end)

remotes.ReturnToHub.OnClientEvent:Connect(function()
	inArena = false
	refreshHint()
end)

remotes.EnterArena.OnClientEvent:Connect(function()
	inArena = true
	refreshHint()
end)

task.spawn(function()
	while true do
		refreshHint()
		task.wait(0.2)
	end
end)
