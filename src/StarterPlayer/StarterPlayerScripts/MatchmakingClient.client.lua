local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchmakingQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
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
title.Size = UDim2.new(1, -16, 0, 24)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 15
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
statusLabel.TextWrapped = true
statusLabel.Text = ""
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

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveButton

local function formatStatus(payload)
	if payload.status == "idle" then
		return ""
	end

	local lines = {
		string.format("Modus: %s", payload.label or payload.modeId or "?"),
		string.format("Spieler: %d / %d", payload.total or 0, payload.maxPlayers or payload.needed or 0),
	}

	if payload.status == "pending" then
		table.insert(lines, "Arena belegt — warte auf Freigabe")
	elseif (payload.total or 0) < (payload.needed or 1) then
		table.insert(lines, string.format("Noch %d Spieler nötig", (payload.needed or 1) - (payload.total or 0)))
	else
		table.insert(lines, "Match startet bald...")
	end

	return table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload or payload.status == "idle" then
		gui.Enabled = false
		return
	end

	title.Text = "Warteschlange"
	statusLabel.Text = formatStatus(payload)
	gui.Enabled = true
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
