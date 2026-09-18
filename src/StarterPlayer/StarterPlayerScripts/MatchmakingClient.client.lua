local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local queueGui = Instance.new("ScreenGui")
queueGui.Name = "MatchmakingQueue"
queueGui.ResetOnSpawn = false
queueGui.Enabled = false
queueGui.DisplayOrder = 20
queueGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 16)
panel.Size = UDim2.fromOffset(320, 150)
panel.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = queueGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Matchmaking"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "StatusLabel"
status.Size = UDim2.new(1, -16, 0, 40)
status.Position = UDim2.fromOffset(8, 36)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 14
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "Warte auf Spieler..."
status.Parent = panel

local roster = Instance.new("TextLabel")
roster.Name = "RosterLabel"
roster.Size = UDim2.new(1, -16, 0, 36)
roster.Position = UDim2.fromOffset(8, 78)
roster.BackgroundTransparency = 1
roster.Font = Enum.Font.Gotham
roster.TextSize = 12
roster.TextColor3 = Color3.fromRGB(180, 190, 210)
roster.TextXAlignment = Enum.TextXAlignment.Left
roster.TextYAlignment = Enum.TextYAlignment.Top
roster.Text = ""
roster.Parent = panel

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

local function formatStatus(payload)
	if payload.status == "pending" then
		return "Arena belegt — Warte auf freien Slot..."
	end
	if payload.status == "ready" then
		return "Match startet gleich..."
	end
	if payload.status == "filling" then
		local remaining = payload.fillRemaining or payload.fillTimeout or 0
		return string.format(
			"Suche Spieler (%d/%d) — Start in %ds",
			payload.count,
			payload.maxPlayers,
			remaining
		)
	end
	return string.format(
		"Warte auf Spieler (%d/%d)",
		payload.count,
		payload.minPlayers
	)
end

local function formatRoster(payload)
	if #payload.players == 0 then
		return "Noch niemand in der Queue"
	end
	return "Spieler: " .. table.concat(payload.players, ", ")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	queueGui.Enabled = true
	title.Text = payload.modeLabel or "Matchmaking"
	status.Text = formatStatus(payload)
	roster.Text = formatRoster(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		queueGui.Enabled = false
	elseif state.phase == "arena" then
		queueGui.Enabled = false
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	queueGui.Enabled = false
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	queueGui.Enabled = false
end)
