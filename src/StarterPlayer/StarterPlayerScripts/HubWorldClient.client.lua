local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 0.92, 0)
hintFrame.Size = UDim2.fromOffset(360, 64)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -16, 0, 28)
titleLabel.Position = UDim2.fromOffset(8, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -16, 0, 24)
hintLabel.Position = UDim2.fromOffset(8, 34)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 14
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintFrame

local hideToken = 0

local function showHint(payload)
	hideToken += 1
	local token = hideToken

	titleLabel.Text = payload.name or "Zone"
	hintLabel.Text = payload.hint or ""
	hintGui.Enabled = true

	task.delay(4, function()
		if token ~= hideToken then return end
		local tween = TweenService:Create(hintFrame, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		tween:Play()
		task.wait(0.3)
		if token ~= hideToken then return end
		hintGui.Enabled = false
		hintFrame.BackgroundTransparency = 0.15
	end)
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)
