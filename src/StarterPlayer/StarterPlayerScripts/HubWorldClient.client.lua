local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZone = nil

local gui = Instance.new("ScreenGui")
gui.Name = "HubZoneUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 0.92, 0)
hintFrame.Size = UDim2.new(0, 420, 0, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(12, 14, 24)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = hintFrame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -16, 0, 28)
hint.Position = UDim2.new(0, 8, 0, 34)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextColor3 = Color3.fromRGB(220, 220, 230)
hint.TextSize = 16
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = hintFrame

local function showZone(payload)
	if payload then
		activeZone = payload
		title.Text = payload.name
		hint.Text = payload.hint or ""
		gui.Enabled = true
	else
		activeZone = nil
		gui.Enabled = false
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZone)

local function tryZoneAction()
	if not activeZone or not activeZone.action then return end
	Remotes.HubZoneAction:FireServer(activeZone.action)
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
