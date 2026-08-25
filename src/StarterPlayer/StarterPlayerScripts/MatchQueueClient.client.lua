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
frame.Size = UDim2.fromOffset(320, 200)
frame.Position = UDim2.new(0.5, -160, 0.5, -100)
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

local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "ModeLabel"
modeLabel.Size = UDim2.new(1, -20, 0, 22)
modeLabel.Position = UDim2.fromOffset(10, 40)
modeLabel.BackgroundTransparency = 1
modeLabel.Font = Enum.Font.GothamMedium
modeLabel.TextSize = 14
modeLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Text = "Modus: Training"
modeLabel.Parent = frame

local countLabel = Instance.new("TextLabel")
countLabel.Name = "CountLabel"
countLabel.Size = UDim2.new(1, -20, 0, 22)
countLabel.Position = UDim2.fromOffset(10, 64)
countLabel.BackgroundTransparency = 1
countLabel.Font = Enum.Font.GothamMedium
countLabel.TextSize = 14
countLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Text = "Spieler: 1"
countLabel.Parent = frame

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, -20, 0, 28)
timerLabel.Position = UDim2.fromOffset(10, 88)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextSize = 20
timerLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Text = "Start in 12s"
timerLabel.Parent = frame

local listLabel = Instance.new("TextLabel")
listLabel.Name = "ListLabel"
listLabel.Size = UDim2.new(1, -20, 0, 40)
listLabel.Position = UDim2.fromOffset(10, 116)
listLabel.BackgroundTransparency = 1
listLabel.Font = Enum.Font.Gotham
listLabel.TextSize = 12
listLabel.TextColor3 = Color3.fromRGB(160, 170, 190)
listLabel.TextXAlignment = Enum.TextXAlignment.Left
listLabel.TextYAlignment = Enum.TextYAlignment.Top
listLabel.TextWrapped = true
listLabel.Text = ""
listLabel.Parent = frame

local leaveBtn = Instance.new("TextButton")
leaveBtn.Size = UDim2.fromOffset(120, 32)
leaveBtn.Position = UDim2.new(0.5, -60, 1, -44)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = leaveBtn

local function hideOthers()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
end

local function updateQueue(payload)
	gui.Enabled = true
	hideOthers()
	modeLabel.Text = ("Modus: %s"):format(payload.modeLabel or "Training")
	countLabel.Text = ("Spieler: %d"):format(payload.playerCount or 1)
	timerLabel.Text = ("Start in %ds"):format(payload.countdown or 0)

	local names = payload.playerNames or {}
	if #names > 0 then
		listLabel.Text = "Warteschlange:\n" .. table.concat(names, ", ")
	else
		listLabel.Text = "Warte auf Gegner..."
	end
end

Remotes.MatchQueueUpdate.OnClientEvent:Connect(updateQueue)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase ~= "Gathering" then
		gui.Enabled = false
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = false
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
	Remotes.LeaveMatchQueue:FireServer()
end)
