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
panel.Size = UDim2.fromOffset(280, 150)
panel.Position = UDim2.new(0.5, -140, 0.5, -75)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.Text = "Matchmaking"
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -20, 0, 52)
statusLabel.Position = UDim2.fromOffset(10, 38)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = ""
statusLabel.Parent = panel

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, -20, 0, 22)
timerLabel.Position = UDim2.fromOffset(10, 92)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 13
timerLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Text = ""
timerLabel.Parent = panel

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(120, 28)
leaveBtn.Position = UDim2.new(1, -130, 1, -38)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Abbrechen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function formatStatus(payload)
	local lines = {
		string.format("Spieler in Warteschlange: %d", payload.playersWaiting or 0),
		string.format("Zielmodus: %s", payload.modeLabel or "?"),
	}
	if payload.position then
		table.insert(lines, string.format("Deine Position: #%d", payload.position))
	end
	return table.concat(lines, "\n")
end

local function updateTimer(payload)
	if payload.status == "starting" then
		timerLabel.Text = "Match startet gleich…"
	elseif payload.secondsUntilStart and payload.secondsUntilStart > 0 then
		timerLabel.Text = string.format("Start in ca. %ds", math.ceil(payload.secondsUntilStart))
	else
		timerLabel.Text = "Warte auf weitere Spieler…"
	end
end

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	statusLabel.Text = formatStatus(payload)
	updateTimer(payload)
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase == "Selecting" or payload.phase == "Countdown" or payload.phase == "Fighting" then
		gui.Enabled = false
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = false
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.LeaveQueue:FireServer()
	gui.Enabled = false
end)
