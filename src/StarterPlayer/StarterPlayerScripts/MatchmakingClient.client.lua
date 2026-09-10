local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(320, 120)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "TitleLabel"
title.Size = UDim2.new(1, -16, 0, 24)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Warteschlange"
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -16, 0, 40)
statusLabel.Position = UDim2.fromOffset(8, 34)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 13
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = "Suche Gegner..."
statusLabel.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(120, 28)
leaveButton.Position = UDim2.fromOffset(8, 82)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveButton

local STATUS_TEXT = {
	waiting = "Warte auf Spieler...",
	pending = "Arena belegt — du bist als Nächstes dran",
	filling = "Lobby füllt sich — Match startet bald",
	starting = "Match startet...",
}

local function formatPlayerList(names)
	if #names == 0 then
		return "Noch keine Spieler"
	end
	return table.concat(names, ", ")
end

local function showQueue(payload)
	if not payload.inQueue and payload.status ~= "starting" then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = string.format("Warteschlange — %s", payload.modeLabel or "Arena")
	local statusKey = payload.status or "waiting"
	local statusLine = STATUS_TEXT[statusKey] or STATUS_TEXT.waiting
	statusLabel.Text = string.format(
		"%s\n%d / %d Spieler\n%s",
		statusLine,
		payload.count or 0,
		payload.max or payload.required or 1,
		formatPlayerList(payload.players or {})
	)
end

Remotes.QueueUpdate.OnClientEvent:Connect(showQueue)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" and not gui.Enabled then
		return
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(state)
	if state.phase == "Selecting" or state.phase == "Countdown" or state.phase == "Fighting" then
		gui.Enabled = false
	end
end)
