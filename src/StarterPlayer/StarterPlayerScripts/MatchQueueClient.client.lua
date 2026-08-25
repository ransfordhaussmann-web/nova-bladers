local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(320, 88)
panel.Position = UDim2.new(0.5, -160, 1, -108)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 22)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Matchmaking-Warteschlange"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "StatusLabel"
status.Size = UDim2.new(1, -16, 0, 36)
status.Position = UDim2.fromOffset(8, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 13
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = ""
status.Parent = panel

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(100, 26)
leaveBtn.Position = UDim2.new(1, -108, 1, -34)
leaveBtn.BackgroundColor3 = Color3.fromRGB(80, 45, 55)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 12
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Abbrechen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.LeaveMatchQueue:FireServer()
	gui.Enabled = false
end)

Remotes.MatchQueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload.queued then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	status.Text = string.format(
		"%d Spieler in der Queue\n%s\nStart in ~%ds",
		payload.count or 1,
		payload.modeLabel or "Modus: Training",
		payload.waitRemaining or 0
	)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = false
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase ~= "Idle" and payload.phase ~= "Selecting" then
		gui.Enabled = false
	end
end)
