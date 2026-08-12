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
panel.Size = UDim2.fromOffset(300, 130)
panel.Position = UDim2.new(0.5, -150, 0.5, -65)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 28)
title.Position = UDim2.fromOffset(10, 10)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Matchmaking"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "StatusLabel"
status.Size = UDim2.new(1, -20, 0, 44)
status.Position = UDim2.fromOffset(10, 40)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 14
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "Warte auf Gegner…"
status.Parent = panel

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(120, 32)
leaveBtn.Position = UDim2.new(1, -130, 1, -42)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 70)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 14
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = leaveBtn

local function hideQueue()
	gui.Enabled = false
end

local function showQueue(payload)
	gui.Enabled = true
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end

	if payload.total >= 3 then
		status.Text = string.format(
			"Position %d / %d\n%s in %ds",
			payload.position or 1,
			payload.total,
			payload.modeLabel or "FFA",
			payload.secondsUntilStart or 0
		)
	elseif payload.total >= 2 then
		status.Text = string.format(
			"Gegner gefunden (%d Spieler)\n%s in %ds",
			payload.total,
			payload.modeLabel or "1v1",
			payload.secondsUntilStart or 0
		)
	else
		status.Text = string.format(
			"Suche Gegner… (%d in Queue)\nSolo-Training in %ds",
			payload.total,
			payload.secondsUntilStart or 0
		)
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		showQueue(payload)
	else
		hideQueue()
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase ~= "Idle" and payload.phase ~= "Gathering" then
		hideQueue()
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideQueue()
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
	hideQueue()
end)
