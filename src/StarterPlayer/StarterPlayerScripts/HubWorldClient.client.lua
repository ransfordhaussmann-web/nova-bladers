local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HubZoneHUD"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "HintFrame"
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 0.92, 0)
frame.Size = UDim2.fromOffset(360, 72)
frame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 220, 100)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Text = ""
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -16, 0, 28)
hint.Position = UDim2.fromOffset(8, 36)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextScaled = true
hint.Font = Enum.Font.Gotham
hint.Text = ""
hint.Parent = frame

local function showZone(payload)
	if not payload then
		if currentZone and currentZone.persistent then
			return
		end
		currentZone = nil
		screenGui.Enabled = false
		return
	end

	if payload.persistent then
		currentZone = payload
	else
		currentZone = payload
	end

	title.Text = payload.name or ""
	hint.Text = payload.hint or ""
	screenGui.Enabled = true
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZone)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if not currentZone or currentZone.persistent then return end
	Remotes.HubZoneAction:FireServer(currentZone.zoneId)
end)
