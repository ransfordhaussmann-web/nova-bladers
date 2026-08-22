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
frame.Size = UDim2.fromOffset(320, 140)
frame.Position = UDim2.new(0.5, -160, 0.35, -70)
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

local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "ModeLabel"
modeLabel.Size = UDim2.new(1, -20, 0, 22)
modeLabel.Position = UDim2.fromOffset(10, 40)
modeLabel.BackgroundTransparency = 1
modeLabel.Font = Enum.Font.GothamMedium
modeLabel.TextSize = 14
modeLabel.TextColor3 = Color3.new(1, 1, 1)
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Text = "Modus: Training"
modeLabel.Parent = frame

local playersLabel = Instance.new("TextLabel")
playersLabel.Name = "PlayersLabel"
playersLabel.Size = UDim2.new(1, -20, 0, 22)
playersLabel.Position = UDim2.fromOffset(10, 64)
playersLabel.BackgroundTransparency = 1
playersLabel.Font = Enum.Font.GothamMedium
playersLabel.TextSize = 14
playersLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
playersLabel.TextXAlignment = Enum.TextXAlignment.Left
playersLabel.Text = "Spieler: 1"
playersLabel.Parent = frame

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "CountdownLabel"
countdownLabel.Size = UDim2.new(1, -20, 0, 22)
countdownLabel.Position = UDim2.fromOffset(10, 86)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Font = Enum.Font.GothamBold
countdownLabel.TextSize = 15
countdownLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
countdownLabel.TextXAlignment = Enum.TextXAlignment.Left
countdownLabel.Text = "Start in: 8s"
countdownLabel.Parent = frame

local cancelBtn = Instance.new("TextButton")
cancelBtn.Size = UDim2.fromOffset(100, 28)
cancelBtn.Position = UDim2.new(1, -110, 1, -38)
cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.TextSize = 13
cancelBtn.TextColor3 = Color3.new(1, 1, 1)
cancelBtn.Text = "Abbrechen"
cancelBtn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = cancelBtn

local function showQueue(payload)
	gui.Enabled = true
	modeLabel.Text = payload.modeLabel or "Modus: Training"
	playersLabel.Text = ("Spieler: %d"):format(payload.players or 1)
	countdownLabel.Text = ("Start in: %ds"):format(payload.countdown or 0)

	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
end

local function hideQueue()
	gui.Enabled = false
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		showQueue(payload)
	else
		hideQueue()
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "queue" then
		-- QueueUpdate will fill in details
	elseif state.phase == "hub" then
		hideQueue()
	elseif state.phase == "arena" then
		hideQueue()
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase ~= "Idle" then
		hideQueue()
	end
end)

cancelBtn.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
	hideQueue()
end)
