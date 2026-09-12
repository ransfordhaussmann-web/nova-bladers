local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchmakingQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(320, 96)
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
title.Text = "Matchmaking"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 36)
status.Position = UDim2.fromOffset(8, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 13
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = ""
status.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(110, 28)
leaveButton.Position = UDim2.new(1, -118, 1, -36)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local function hideQueue()
	gui.Enabled = false
end

local function showQueue(payload)
	gui.Enabled = true
	title.Text = string.format("Queue: %s", payload.modeLabel or "Arena")
	status.Text = string.format(
		"%s\n(%d/%d Spieler)",
		payload.message or "Warte…",
		payload.playersInQueue or 0,
		payload.maxPlayers or payload.playersInQueue or 0
	)

	if payload.status == "pending" then
		title.TextColor3 = Color3.fromRGB(255, 180, 80)
	elseif payload.status == "ready" then
		title.TextColor3 = Color3.fromRGB(100, 220, 140)
	else
		title.TextColor3 = Color3.fromRGB(120, 180, 255)
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		showQueue(payload)
	else
		hideQueue()
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)
