local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "QueueOverlay"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(300, 140)
frame.Position = UDim2.new(0.5, -150, 0.35, 0)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
frame.BackgroundTransparency = 0.1
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
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.Text = "Warteschlange"
title.Parent = frame

local countLabel = Instance.new("TextLabel")
countLabel.Name = "CountLabel"
countLabel.Size = UDim2.new(1, -20, 0, 24)
countLabel.Position = UDim2.fromOffset(10, 40)
countLabel.BackgroundTransparency = 1
countLabel.Font = Enum.Font.GothamMedium
countLabel.TextSize = 15
countLabel.TextColor3 = Color3.new(1, 1, 1)
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Text = "Spieler: 1"
countLabel.Parent = frame

local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "ModeLabel"
modeLabel.Size = UDim2.new(1, -20, 0, 20)
modeLabel.Position = UDim2.fromOffset(10, 66)
modeLabel.BackgroundTransparency = 1
modeLabel.Font = Enum.Font.Gotham
modeLabel.TextSize = 13
modeLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Text = "Modus: Training"
modeLabel.Parent = frame

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, -20, 0, 20)
timerLabel.Position = UDim2.fromOffset(10, 88)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextSize = 14
timerLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Text = "Start in: --"
timerLabel.Parent = frame

local leaveBtn = Instance.new("TextButton")
leaveBtn.Size = UDim2.fromOffset(100, 28)
leaveBtn.Position = UDim2.new(1, -110, 1, -38)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	countLabel.Text = ("Spieler: %d"):format(payload.count or 1)
	modeLabel.Text = payload.modeLabel or "Modus: Training"
	timerLabel.Text = ("Start in: %ds"):format(payload.waitRemaining or 0)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = false
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase ~= "Idle" then
		gui.Enabled = false
	end
end)
