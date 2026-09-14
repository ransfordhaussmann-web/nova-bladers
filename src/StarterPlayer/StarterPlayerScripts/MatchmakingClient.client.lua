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
panel.Size = UDim2.fromOffset(320, 140)
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
title.Text = "Matchmaking"
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -16, 0, 48)
statusLabel.Position = UDim2.fromOffset(8, 34)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 13
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextWrapped = true
statusLabel.Text = "Warte auf Spieler..."
statusLabel.Parent = panel

local playersLabel = Instance.new("TextLabel")
playersLabel.Name = "PlayersLabel"
playersLabel.Size = UDim2.new(1, -120, 0, 40)
playersLabel.Position = UDim2.fromOffset(8, 86)
playersLabel.BackgroundTransparency = 1
playersLabel.Font = Enum.Font.Gotham
playersLabel.TextSize = 11
playersLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
playersLabel.TextXAlignment = Enum.TextXAlignment.Left
playersLabel.TextYAlignment = Enum.TextYAlignment.Top
playersLabel.TextWrapped = true
playersLabel.Text = ""
playersLabel.Parent = panel

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(100, 32)
leaveBtn.Position = UDim2.new(1, -108, 1, -40)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function statusText(payload)
	if payload.status == "pending" then
		return "Arena belegt — du bist in der Warteschlange"
	elseif payload.status == "ready" then
		return "Match startet gleich..."
	elseif payload.status == "filling" and payload.fillRemaining then
		return string.format("Start in %ds (%d/%d Spieler)", payload.fillRemaining, payload.count, payload.maxPlayers)
	end
	return string.format("Warte auf Spieler (%d/%d)", payload.count, payload.minPlayers)
end

local function applyUpdate(payload)
	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = "Queue: " .. (payload.modeLabel or payload.modeId or "?")
	statusLabel.Text = statusText(payload)

	local lines = {}
	for _, name in payload.players or {} do
		table.insert(lines, "• " .. name)
	end
	playersLabel.Text = table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyUpdate)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = false
	end
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
