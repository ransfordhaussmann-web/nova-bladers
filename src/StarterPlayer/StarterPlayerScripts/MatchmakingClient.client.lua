local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchmakingQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 12
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 72)
panel.Size = UDim2.fromOffset(300, 120)
panel.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
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
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(180, 220, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Warteschlange"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 44)
status.Position = UDim2.fromOffset(8, 36)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 14
status.TextColor3 = Color3.fromRGB(210, 210, 220)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = "Suche Gegner..."
status.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.AnchorPoint = Vector2.new(1, 1)
leaveButton.Position = UDim2.new(1, -8, 1, -8)
leaveButton.Size = UDim2.fromOffset(110, 28)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 14
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local function applyPayload(payload)
	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = payload.modeLabel or "Warteschlange"

	local lines = {
		string.format(
			"Spieler: %d / %d",
			payload.queueSize or 1,
			payload.maxPlayers or 1
		),
	}

	if payload.pending then
		table.insert(lines, "Arena belegt — warte auf freien Slot")
	else
		table.insert(lines, "Warte auf weitere Spieler...")
	end

	status.Text = table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyPayload)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)
