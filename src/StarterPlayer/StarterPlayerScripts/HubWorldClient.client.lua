local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local currentZone = nil

local gui = Instance.new("ScreenGui")
gui.Name = "HubHints"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.fromOffset(420, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
hintFrame.BackgroundTransparency = 0.15
hintFrame.Visible = false
hintFrame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(255, 220, 100)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = hintFrame

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(1, -16, 0, 24)
subtitle.Position = UDim2.fromOffset(8, 36)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 15
subtitle.TextColor3 = Color3.new(1, 1, 1)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = hintFrame

local function showHint(payload)
	if not payload then
		currentZone = nil
		hintFrame.Visible = false
		return
	end

	currentZone = payload
	title.Text = payload.name or ""
	subtitle.Text = payload.hint or ""
	hintFrame.Visible = true
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local function tryInteract()
	if not currentZone or currentZone.action == "none" then
		return
	end
	Remotes.HubZoneAction:FireServer(currentZone.zoneId)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == HubConfig.INTERACT_KEY then
		tryInteract()
	end
end)
