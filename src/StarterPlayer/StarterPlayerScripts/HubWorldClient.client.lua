local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HubWorldUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "ZoneHint"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.new(0, 420, 0, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.15
hintFrame.Visible = false
hintFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -16, 0, 28)
titleLabel.Position = UDim2.new(0, 8, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -16, 0, 28)
hintLabel.Position = UDim2.new(0, 8, 0, 36)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 16
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintFrame

local function showZoneHint(payload)
	if not payload or not payload.zoneId then
		currentZone = nil
		hintFrame.Visible = false
		return
	end

	currentZone = payload
	titleLabel.Text = payload.name or ""
	hintLabel.Text = payload.hint or ""
	hintFrame.Visible = true
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZoneHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if not currentZone or not currentZone.action then return end
	Remotes.HubZoneAction:FireServer(currentZone.zoneId)
end)
