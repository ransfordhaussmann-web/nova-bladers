local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = playerGui

local hintFrame = Instance.new("Frame")
hintFrame.Name = "Panel"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -120)
hintFrame.Size = UDim2.fromOffset(360, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -16, 0.5, 0)
titleLabel.Position = UDim2.fromOffset(8, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -16, 0.45, 0)
hintLabel.Position = UDim2.new(0, 8, 0.5, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextColor3 = Color3.fromRGB(190, 200, 220)
hintLabel.TextScaled = true
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintFrame

local function setZoneHint(payload)
	currentZone = payload
	if payload then
		titleLabel.Text = payload.name or ""
		hintLabel.Text = payload.hint or ""
		hintGui.Enabled = true
	else
		hintGui.Enabled = false
	end
end

remotes.HubZoneHint.OnClientEvent:Connect(setZoneHint)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= HubConfig.INTERACT_KEY then return end
	if not currentZone or currentZone.action == "none" then return end

	remotes.HubZoneAction:FireServer(currentZone.zoneId)
end)
