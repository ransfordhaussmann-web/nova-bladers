local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(300, 140)
frame.Position = UDim2.new(0.5, -150, 0.5, -70)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Matchmaking"
title.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -20, 0, 52)
statusLabel.Position = UDim2.fromOffset(10, 40)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.fromRGB(180, 200, 230)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = ""
statusLabel.Parent = frame

local cancelBtn = Instance.new("TextButton")
cancelBtn.Size = UDim2.fromOffset(120, 32)
cancelBtn.Position = UDim2.new(0.5, -60, 1, -44)
cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.TextSize = 13
cancelBtn.TextColor3 = Color3.new(1, 1, 1)
cancelBtn.Text = "Abbrechen"
cancelBtn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = cancelBtn

cancelBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		gui.Enabled = true
		statusLabel.Text = string.format(
			"Modus: %s\nSpieler: %d / %d\nMax. Wartezeit: %ds",
			payload.modeLabel or "?",
			payload.waiting or 0,
			payload.needed or 1,
			payload.timeLeft or 0
		)
	else
		gui.Enabled = false
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase ~= "Idle" and payload.phase ~= "Gathering" then
		gui.Enabled = false
	end
end)
