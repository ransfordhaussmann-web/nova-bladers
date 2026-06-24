local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "Panel"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.fromOffset(360, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -16, 0, 28)
titleLabel.Position = UDim2.fromOffset(8, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextSize = 18
titleLabel.Text = ""
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -16, 0, 22)
hintLabel.Position = UDim2.fromOffset(8, 34)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextSize = 14
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local actionLabel = Instance.new("TextLabel")
actionLabel.Name = "Action"
actionLabel.Size = UDim2.new(1, -16, 0, 18)
actionLabel.Position = UDim2.fromOffset(8, 52)
actionLabel.BackgroundTransparency = 1
actionLabel.Font = Enum.Font.Gotham
actionLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
actionLabel.TextXAlignment = Enum.TextXAlignment.Left
actionLabel.TextSize = 13
actionLabel.Text = ""
actionLabel.Parent = hintFrame

local activeZoneId

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload.entering then
		activeZoneId = payload.zoneId
		titleLabel.Text = payload.name or ""
		hintLabel.Text = payload.hint or ""
		actionLabel.Text = payload.actionLabel and ("[E] " .. payload.actionLabel) or ""
		hintGui.Enabled = true
	elseif payload.zoneId == activeZoneId or not payload.zoneId then
		activeZoneId = nil
		hintGui.Enabled = false
	end
end)

Remotes.HubZoneAction.OnClientEvent:Connect(function(action)
	if action == "ViewLeaderboard" then
		titleLabel.Text = "Ruhmeshalle"
		hintLabel.Text = "Top-Spieler stehen am Board vor dir."
		actionLabel.Text = ""
		hintGui.Enabled = true
		task.delay(3, function()
			if activeZoneId == nil then
				hintGui.Enabled = false
			end
		end)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
