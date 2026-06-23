local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil

local gui = Instance.new("ScreenGui")
gui.Name = "HubZoneUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "HintFrame"
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 1, -120)
frame.Size = UDim2.new(0, 360, 0, 90)
frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
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
title.TextColor3 = Color3.fromRGB(255, 220, 80)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -16, 0, 22)
hint.Position = UDim2.new(0, 8, 0, 36)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.new(1, 1, 1)
hint.Font = Enum.Font.Gotham
hint.TextSize = 16
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

local action = Instance.new("TextLabel")
action.Name = "Action"
action.Size = UDim2.new(1, -16, 0, 20)
action.Position = UDim2.new(0, 8, 0, 62)
action.BackgroundTransparency = 1
action.TextColor3 = Color3.fromRGB(160, 200, 255)
action.Font = Enum.Font.GothamMedium
action.TextSize = 15
action.TextXAlignment = Enum.TextXAlignment.Left
action.Parent = frame

local function showZone(payload)
	if not payload then
		currentZone = nil
		gui.Enabled = false
		return
	end
	currentZone = payload.zoneId
	title.Text = payload.name
	hint.Text = payload.hint
	action.Text = string.format("[E] %s", payload.actionLabel)
	gui.Enabled = true
end

local function fireZoneAction()
	if not currentZone then return end
	Remotes.HubZoneAction:FireServer(currentZone)
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZone)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		fireZoneAction()
	end
end)
