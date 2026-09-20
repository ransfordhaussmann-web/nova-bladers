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
panel.Size = UDim2.fromOffset(300, 120)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
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
statusLabel.Size = UDim2.new(1, -16, 0, 44)
statusLabel.Position = UDim2.fromOffset(8, 34)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 13
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextWrapped = true
statusLabel.Text = "Suche Gegner..."
statusLabel.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(120, 28)
leaveButton.Position = UDim2.new(1, -128, 1, -36)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local inQueue = false

local function formatPlayerList(names)
	if #names == 0 then
		return "—"
	end
	return table.concat(names, ", ")
end

local function updatePanel(payload)
	gui.Enabled = true
	inQueue = true

	title.Text = "Warteschlange — " .. (payload.modeLabel or payload.modeId or "?")

	local statusText
	if payload.status == "pending" then
		statusText = string.format(
			"Arena belegt — %d/%d Spieler warten\n%s",
			payload.count or 0,
			payload.needed or 0,
			formatPlayerList(payload.players or {})
		)
	else
		statusText = string.format(
			"%d/%d Spieler\n%s",
			payload.count or 0,
			payload.needed or 0,
			formatPlayerList(payload.players or {})
		)
	end

	statusLabel.Text = statusText
end

local function hidePanel()
	inQueue = false
	gui.Enabled = false
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload and payload.count and payload.count > 0 then
		updatePanel(payload)
	else
		hidePanel()
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function(state)
	if state.phase == "Selecting" or state.phase == "Countdown" or state.phase == "Fighting" then
		hidePanel()
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	if inQueue then
		Remotes.QueueLeave:FireServer()
		hidePanel()
	end
end)
