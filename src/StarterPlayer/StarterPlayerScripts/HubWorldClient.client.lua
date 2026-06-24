local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil

local gui = Instance.new("ScreenGui")
gui.Name = "HubZoneHint"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "HintFrame"
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 1, -80)
frame.Size = UDim2.fromOffset(400, 70)
frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 28)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(100, 180, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Text = ""
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -20, 0, 24)
hint.Position = UDim2.fromOffset(10, 38)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextScaled = true
hint.Font = Enum.Font.Gotham
hint.Text = ""
hint.Parent = frame

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if not payload.active then
		currentZone = nil
		gui.Enabled = false
		return
	end

	currentZone = payload.zoneId
	title.Text = payload.name or ""
	hint.Text = payload.hint or ""
	gui.Enabled = true
end)

local function tryZoneAction()
	if not currentZone then return end
	Remotes.HubZoneAction:FireServer(currentZone)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)
