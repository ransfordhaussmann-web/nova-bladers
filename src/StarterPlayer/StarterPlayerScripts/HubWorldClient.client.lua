local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil

local gui = Instance.new("ScreenGui")
gui.Name = "HubZoneHint"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "HintFrame"
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 1, -120)
frame.Size = UDim2.fromOffset(360, 88)
frame.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "ZoneName"
title.Size = UDim2.new(1, -24, 0, 36)
title.Position = UDim2.fromOffset(12, 10)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "HintText"
hint.Size = UDim2.new(1, -24, 0, 28)
hint.Position = UDim2.fromOffset(12, 48)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 16
hint.TextColor3 = Color3.fromRGB(190, 195, 210)
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

local function hideHint()
	currentZone = nil
	gui.Enabled = false
end

remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if not payload.zoneId then
		hideHint()
		return
	end

	currentZone = payload.zoneId
	title.Text = payload.zoneName or "Zone"
	hint.Text = payload.hint or ""
	gui.Enabled = true
end)

local function tryZoneAction()
	if not currentZone then return end
	remotes.HubZoneAction:FireServer(currentZone)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)
