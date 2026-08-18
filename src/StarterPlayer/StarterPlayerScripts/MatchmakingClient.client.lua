local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.Size = UDim2.fromOffset(320, 130)
frame.Position = UDim2.new(0.5, -160, 0.5, -65)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 32)
title.Position = UDim2.fromOffset(10, 10)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Matchmaking"
title.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -20, 0, 44)
statusLabel.Position = UDim2.fromOffset(10, 42)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.fromRGB(180, 200, 230)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = ""
statusLabel.Parent = frame

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(140, 32)
leaveBtn.Position = UDim2.new(0.5, -70, 1, -42)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 70)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Queue verlassen"
leaveBtn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function hide()
	gui.Enabled = false
end

local function show(payload)
	gui.Enabled = true
	local count = payload.count or 1
	local modeLabel = payload.modeLabel or "Training"
	statusLabel.Text = string.format(
		"%d Spieler in der Warteschlange\nModus: %s\nWarte auf Match-Start…",
		count,
		modeLabel
	)
end

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.MatchmakingLeave:FireServer()
	hide()
	Remotes.ReturnToHub:FireServer()
end)

Remotes.MatchmakingUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		show(payload)
	else
		hide()
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hide()
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase == "Selecting" or payload.phase == "Countdown" or payload.phase == "Fighting" then
		hide()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hide()
end)
