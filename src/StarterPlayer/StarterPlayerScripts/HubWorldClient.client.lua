local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HubZoneHint"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -80)
hintFrame.Size = UDim2.fromOffset(320, 70)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 35)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -20, 0, 28)
titleLabel.Position = UDim2.fromOffset(10, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -20, 0, 22)
hintLabel.Position = UDim2.fromOffset(10, 36)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 15
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintFrame

local function showZoneHint(zone)
	if zone then
		currentZone = zone
		titleLabel.Text = zone.name
		hintLabel.Text = zone.hint .. "  [E]"
		screenGui.Enabled = true
	else
		currentZone = nil
		screenGui.Enabled = false
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZoneHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local beySelect = player.PlayerGui:FindFirstChild("BeySelect")
	if beySelect then
		beySelect.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not currentZone then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		Remotes.HubZoneAction:FireServer(currentZone.id)
	end
end)
