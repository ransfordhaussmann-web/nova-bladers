local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchmakingQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(320, 110)
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
statusLabel.Size = UDim2.new(1, -100, 0, 44)
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
leaveButton.Size = UDim2.fromOffset(84, 32)
leaveButton.Position = UDim2.new(1, -92, 1, -40)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local function formatStatus(payload)
	if payload.status == "left" or payload.status == "error" then
		return ""
	end

	local lines = {}
	table.insert(lines, string.format("%s — %d/%d Spieler", payload.modeLabel or "Queue", payload.queueSize or 0, payload.maxPlayers or 0))

	if payload.status == "pending" or payload.arenaBusy then
		table.insert(lines, "Arena belegt — warte auf freies Match")
	elseif payload.status == "ready" then
		table.insert(lines, "Match startet gleich…")
	elseif payload.fillRemaining and payload.fillRemaining > 0 then
		table.insert(lines, string.format("Start in ~%ds", math.ceil(payload.fillRemaining)))
	else
		table.insert(lines, "Warte auf weitere Spieler…")
	end

	return table.concat(lines, "\n")
end

local function showQueue(payload)
	if payload.status == "left" or payload.status == "error" then
		gui.Enabled = false
		statusLabel.Text = ""
		return
	end

	gui.Enabled = true
	title.Text = "Warteschlange — " .. (payload.modeLabel or "")
	statusLabel.Text = formatStatus(payload)
end

Remotes.QueueUpdate.OnClientEvent:Connect(showQueue)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
