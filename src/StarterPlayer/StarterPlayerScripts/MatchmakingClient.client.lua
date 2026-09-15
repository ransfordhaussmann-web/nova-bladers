local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local queueGui = Instance.new("ScreenGui")
queueGui.Name = "MatchmakingQueue"
queueGui.ResetOnSpawn = false
queueGui.Enabled = false
queueGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "QueuePanel"
panel.Size = UDim2.fromOffset(280, 120)
panel.Position = UDim2.new(0.5, -140, 0, 80)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = queueGui

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

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 44)
status.Position = UDim2.fromOffset(8, 34)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 13
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = ""
status.Parent = panel

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(120, 30)
leaveBtn.Position = UDim2.new(1, -128, 1, -38)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function formatStatus(payload)
	if not payload.inQueue then
		return ""
	end

	local countText = string.format("%d / %d Spieler", payload.players, payload.minPlayers)
	if payload.pending or payload.arenaBusy then
		return string.format(
			"%s\n%s\n⏳ Arena belegt — warte...",
			payload.modeLabel,
			countText
		)
	end

	if payload.players >= payload.minPlayers then
		return string.format(
			"%s\n%s\n✓ Match startet bald...",
			payload.modeLabel,
			countText
		)
	end

	return string.format(
		"%s\n%s\nWarte auf Gegner...",
		payload.modeLabel,
		countText
	)
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload.inQueue then
		queueGui.Enabled = false
		return
	end

	queueGui.Enabled = true
	title.Text = "Warteschlange — " .. (payload.modeLabel or "")
	status.Text = formatStatus(payload)
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	queueGui.Enabled = false
end)
