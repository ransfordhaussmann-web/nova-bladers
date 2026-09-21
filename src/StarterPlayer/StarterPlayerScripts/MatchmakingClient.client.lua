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
panel.Position = UDim2.new(0.5, 0, 0, 16)
panel.Size = UDim2.fromOffset(320, 150)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 28)
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
statusLabel.Size = UDim2.new(1, -16, 0, 52)
statusLabel.Position = UDim2.fromOffset(8, 36)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 13
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextWrapped = true
statusLabel.Text = ""
statusLabel.Parent = panel

local playersLabel = Instance.new("TextLabel")
playersLabel.Name = "PlayersLabel"
playersLabel.Size = UDim2.new(1, -16, 0, 36)
playersLabel.Position = UDim2.fromOffset(8, 88)
playersLabel.BackgroundTransparency = 1
playersLabel.Font = Enum.Font.Gotham
playersLabel.TextSize = 12
playersLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
playersLabel.TextXAlignment = Enum.TextXAlignment.Left
playersLabel.TextYAlignment = Enum.TextYAlignment.Top
playersLabel.TextWrapped = true
playersLabel.Text = ""
playersLabel.Parent = panel

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

local STATUS_TEXT = {
	waiting = "Warte auf Spieler…",
	pending = "Arena belegt — du bist als Nächstes dran",
	ready = "Match startet gleich…",
}

local function formatPlayerList(names)
	if not names or #names == 0 then
		return "Noch keine Spieler in der Queue"
	end
	return "In Queue: " .. table.concat(names, ", ")
end

local function applyQueueUpdate(payload)
	if payload.status == "left" or not payload.modeId then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = "Warteschlange — " .. (payload.modeLabel or payload.modeId)

	local statusKey = payload.status or "waiting"
	local statusText = STATUS_TEXT[statusKey] or STATUS_TEXT.waiting
	statusLabel.Text = string.format(
		"%s\n%d / %d Spieler",
		statusText,
		payload.players or 0,
		payload.maxPlayers or 0
	)

	local positionText = ""
	if payload.position then
		positionText = string.format("Position: %d\n", payload.position)
	end
	playersLabel.Text = positionText .. formatPlayerList(payload.playerNames)
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueUpdate)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		gui.Enabled = false
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
