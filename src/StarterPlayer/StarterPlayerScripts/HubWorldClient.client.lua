local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local currentZone = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -120)
hintFrame.Size = UDim2.fromOffset(360, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.fromOffset(12, 8)
titleLabel.Size = UDim2.new(1, -24, 0, 24)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.BackgroundTransparency = 1
hintLabel.Position = UDim2.fromOffset(12, 32)
hintLabel.Size = UDim2.new(1, -24, 0, 28)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 16
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintFrame

local function hideHint()
	currentZone = nil
	hintGui.Enabled = false
end

local function showHint(payload)
	if not payload.visible then
		hideHint()
		return
	end
	currentZone = payload
	titleLabel.Text = payload.name or "Zone"
	hintLabel.Text = payload.hint or ""
	hintGui.Enabled = true
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local function tryZoneAction()
	if not currentZone or not currentZone.action then return end
	if currentZone.action == "leaderboard" then
		return
	end
	Remotes.HubZoneAction:FireServer(currentZone.action)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)
