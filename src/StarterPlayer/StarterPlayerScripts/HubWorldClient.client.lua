local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HubZoneHint"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintPanel"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.fromOffset(420, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local title = Instance.new("TextLabel")
title.Name = "ZoneName"
title.Size = UDim2.new(1, -20, 0, 28)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(120, 200, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = hintFrame

local hint = Instance.new("TextLabel")
hint.Name = "HintText"
hint.Size = UDim2.new(1, -20, 0, 32)
hint.Position = UDim2.fromOffset(10, 34)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 14
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextWrapped = true
hint.Parent = hintFrame

local hideToken = 0

local function showHint(payload)
	hideToken += 1
	local token = hideToken

	title.Text = payload.zoneName or "Zone"
	hint.Text = payload.hint or ""
	screenGui.Enabled = true

	task.delay(4, function()
		if hideToken == token then
			screenGui.Enabled = false
		end
	end)
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
