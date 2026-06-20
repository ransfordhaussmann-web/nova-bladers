local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "HubZoneHint"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "HintFrame"
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 1, -80)
frame.Size = UDim2.fromOffset(320, 72)
frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
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
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Text = ""
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -16, 0, 22)
hint.Position = UDim2.fromOffset(8, 38)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.fromRGB(180, 190, 210)
hint.TextScaled = true
hint.Font = Enum.Font.Gotham
hint.Text = ""
hint.Parent = frame

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if not payload then
		gui.Enabled = false
		return
	end

	title.Text = payload.name or "Zone"
	hint.Text = payload.hint or ""
	gui.Enabled = true
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
