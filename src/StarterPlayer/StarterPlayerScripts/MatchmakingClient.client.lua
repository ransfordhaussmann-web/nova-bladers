local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local STATUS_TEXT = {
	idle = "",
	queued = "In Warteschlange",
	pending = "Arena belegt — warte…",
	starting = "Match startet…",
}

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "QueuePanel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(280, 88)
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

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -16, 0, 36)
statusLabel.Position = UDim2.fromOffset(8, 30)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 13
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = ""
statusLabel.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(100, 26)
leaveButton.Position = UDim2.new(1, -108, 1, -34)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 12
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveButton

local function formatQueueText(payload)
	local modeLabel = payload.modeLabel or "Arena"
	local count = payload.count or 0
	local needed = payload.needed or 1
	local maxPlayers = payload.maxPlayers or needed
	local status = payload.status or "queued"

	local lines = {
		string.format("%s — %d / %d", modeLabel, count, maxPlayers),
	}

	if count < needed then
		table.insert(lines, string.format("Noch %d Spieler nötig", needed - count))
	end

	local statusLine = STATUS_TEXT[status]
	if statusLine and statusLine ~= "" then
		table.insert(lines, statusLine)
	end

	return table.concat(lines, "\n")
end

local function applyQueueUpdate(payload)
	if not payload or not payload.inQueue then
		gui.Enabled = false
		return
	end

	if payload.status == "starting" then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = "Warteschlange — " .. (payload.modeLabel or "Arena")
	statusLabel.Text = formatQueueText(payload)
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueUpdate)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
