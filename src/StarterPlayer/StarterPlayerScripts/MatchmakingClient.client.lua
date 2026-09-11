local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "QueuePanel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(300, 110)
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
title.Text = "Warteschlange"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 44)
status.Position = UDim2.fromOffset(8, 32)
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
leaveBtn.Size = UDim2.fromOffset(120, 28)
leaveBtn.Position = UDim2.new(1, -128, 1, -36)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local STATUS_TEXT = {
	waiting = "Warte auf Spieler…",
	filling = "Fülle Lobby…",
	pending = "Arena belegt — warte…",
	starting = "Match startet…",
}

local function formatStatus(payload)
	local lines = {
		string.format("%s — %d/%d Spieler", payload.modeLabel, payload.playersInQueue, payload.maxPlayers),
	}
	local statusLine = STATUS_TEXT[payload.status] or "In Warteschlange…"
	if payload.status == "filling" and payload.secondsLeft then
		statusLine = string.format("Start in %ds…", payload.secondsLeft)
	end
	table.insert(lines, statusLine)
	return table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = "Warteschlange: " .. payload.modeLabel
	status.Text = formatStatus(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		gui.Enabled = false
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
