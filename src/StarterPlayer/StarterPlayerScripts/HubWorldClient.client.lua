local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui
local currentZone

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubHint"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0.92, 0)
	label.Size = UDim2.fromOffset(400, 36)
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 16
	label.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	hintGui = screen
	return screen
end

local function getCharacterRoot()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function findNearestZone()
	local root = getCharacterRoot()
	if not root then return nil end

	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if not hub then return nil end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return nil end

	local nearest
	local nearestDist = HubConfig.INTERACT_RANGE

	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			local dist = (root.Position - zonePart.Position).Magnitude
			if dist <= nearestDist then
				nearestDist = dist
				nearest = zonePart
			end
		end
	end

	return nearest
end

local function updateZoneHint()
	local zone = findNearestZone()
	local gui = ensureHintGui()

	if zone then
		currentZone = zone
		gui.Enabled = true
		gui.HintLabel.Text = zone:GetAttribute("Hint") or "Drücke E"
	else
		currentZone = nil
		gui.Enabled = false
	end
end

local function fireZoneAction()
	if not currentZone then return end
	local action = currentZone:GetAttribute("Action")
	if action == "EnterArena" then
		Remotes.EnterArena:FireServer()
	elseif action == "OpenBeySelect" then
		Remotes.OpenBeySelect:FireServer()
	elseif action == "ShowHallPanel" then
		Remotes.ShowHallPanel:FireServer()
	end
end

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		fireZoneAction()
	end
end)

task.spawn(function()
	while true do
		updateZoneHint()
		task.wait(0.2)
	end
end)
