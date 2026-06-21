local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZoneId = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 1, -72)
frame.Size = UDim2.new(0, 360, 0, 72)
frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.new(0, 8, 0, 8)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 220, 120)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -16, 0, 24)
hint.Position = UDim2.new(0, 8, 0, 38)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.new(1, 1, 1)
hint.Font = Enum.Font.Gotham
hint.TextSize = 16
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload.zoneId then
		currentZoneId = payload.zoneId
		title.Text = payload.name or ""
		hint.Text = payload.hint or ""
		hintGui.Enabled = true
	else
		currentZoneId = nil
		hintGui.Enabled = false
	end
end)

local function tryZoneAction()
	if not currentZoneId then return end
	Remotes.HubZoneAction:FireServer(currentZoneId)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
