local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil

local gui = Instance.new("ScreenGui")
gui.Name = "HubZoneHint"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 1, -120)
frame.Size = UDim2.fromOffset(320, 72)
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
title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 220, 120)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -16, 0, 32)
hint.Position = UDim2.fromOffset(8, 34)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.new(1, 1, 1)
hint.Font = Enum.Font.Gotham
hint.TextSize = 15
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextWrapped = true
hint.Parent = frame

local function showZone(payload)
	if not payload then
		currentZone = nil
		gui.Enabled = false
		return
	end
	currentZone = payload
	title.Text = payload.name or ""
	hint.Text = payload.hint or ""
	gui.Enabled = true
end

remotes.HubZoneHint.OnClientEvent:Connect(showZone)

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not currentZone then return end
	if currentZone.action == "none" then return end
	if input.KeyCode ~= Enum.KeyCode.E and input.KeyCode ~= Enum.KeyCode.ButtonX then return end
	remotes.HubZoneAction:FireServer(currentZone.zoneId)
end)
