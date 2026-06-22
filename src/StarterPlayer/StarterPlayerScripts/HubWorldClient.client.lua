local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "Panel"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -120)
hintFrame.Size = UDim2.fromOffset(320, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -16, 0, 24)
titleLabel.Position = UDim2.fromOffset(8, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -16, 0, 20)
hintLabel.Position = UDim2.fromOffset(8, 30)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 13
hintLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintFrame

local currentZoneId

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if not payload then
		hintGui.Enabled = false
		currentZoneId = nil
		return
	end

	currentZoneId = payload.zoneId
	titleLabel.Text = payload.label or ""
	hintLabel.Text = payload.hint or ""
	hintGui.Enabled = true
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not currentZoneId then return end
	if input.KeyCode == Enum.KeyCode.E then
		Remotes.HubZoneAction:FireServer(currentZoneId)
	end
end)
