local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(280, 120)
panel.Position = UDim2.new(0.5, -140, 0, 16)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(140, 200, 255)
title.Text = "⏳ Matchmaking"
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -20, 0, 44)
statusLabel.Position = UDim2.fromOffset(10, 34)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = ""
statusLabel.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Size = UDim2.fromOffset(100, 28)
leaveButton.Position = UDim2.new(1, -110, 1, -38)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveButton.BorderSizePixel = 0
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.matchFound then
		statusLabel.Text = "Match gefunden!"
		task.delay(1, function()
			gui.Enabled = false
		end)
		return
	end

	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end

	statusLabel.Text = string.format(
		"%s\nSpieler: %d / %d",
		payload.modeLabel or "Warteschlange",
		payload.count or 0,
		payload.needed or 1
	)
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase == "Selecting" or payload.phase == "Countdown" or payload.phase == "Fighting" then
		gui.Enabled = false
	end
end)
