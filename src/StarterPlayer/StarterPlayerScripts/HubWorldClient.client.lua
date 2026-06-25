local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "HubZoneHint"
gui.ResetOnSpawn = false
gui.Enabled = true
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "HintFrame"
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 1, -80)
frame.Size = UDim2.new(0, 360, 0, 72)
frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0.45, 0)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Text = ""
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -16, 0.4, 0)
hint.Position = UDim2.new(0, 8, 0.5, 0)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.fromRGB(180, 190, 210)
hint.TextScaled = true
hint.Font = Enum.Font.Gotham
hint.Text = ""
hint.Parent = frame

local activeZone

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload.zone then
		activeZone = payload.zone
		title.Text = payload.name or ""
		hint.Text = payload.hint or ""
		frame.Visible = true
	else
		activeZone = nil
		frame.Visible = false
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if not activeZone then return end
	Remotes.HubInteract:FireServer()
end)
