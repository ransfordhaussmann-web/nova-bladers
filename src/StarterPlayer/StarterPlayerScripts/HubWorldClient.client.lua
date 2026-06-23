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
frame.Position = UDim2.new(0.5, 0, 0.92, 0)
frame.Size = UDim2.new(0, 360, 0, 72)
frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.new(0, 8, 0, 8)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 220, 100)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Text = ""
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -16, 0, 24)
hint.Position = UDim2.new(0, 8, 0, 38)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextScaled = true
hint.Font = Enum.Font.Gotham
hint.Text = ""
hint.Parent = frame

local function showZone(zone)
	currentZone = zone
	if zone then
		title.Text = zone.name
		hint.Text = zone.hint or ""
		gui.Enabled = true
	else
		gui.Enabled = false
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZone)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if not currentZone or currentZone.action == "none" then return end
	Remotes.HubZoneAction:FireServer(currentZone.id)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
