local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 16)
panel.Size = UDim2.fromOffset(320, 132)
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
title.Text = "Matchmaking"
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -16, 0, 48)
statusLabel.Position = UDim2.fromOffset(8, 36)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextWrapped = true
statusLabel.Text = "Warte auf Spieler..."
statusLabel.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(120, 30)
leaveButton.Position = UDim2.new(1, -128, 1, -38)
leaveButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local function hideLobby()
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

local function showLobby()
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = true
	end
end

local function formatStatus(payload)
	local countText = string.format("%d / %d Spieler", payload.count, payload.maxPlayers)

	if payload.status == "pending" then
		return string.format(
			"Arena belegt — %s\n%s\nWarteschlange startet, sobald die Arena frei ist.",
			payload.modeLabel,
			countText
		)
	end

	if payload.status == "filling" and payload.fillSecondsLeft then
		return string.format(
			"%s\n%s\nStart in %ds (min. %d Spieler)",
			payload.modeLabel,
			countText,
			payload.fillSecondsLeft,
			payload.minPlayers
		)
	end

	if payload.count < payload.minPlayers then
		return string.format(
			"%s\n%s\nWarte auf mindestens %d Spieler...",
			payload.modeLabel,
			countText,
			payload.minPlayers
		)
	end

	return string.format("%s\n%s\nMatch startet gleich...", payload.modeLabel, countText)
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	gui.Enabled = true
	hideLobby()
	title.Text = "Matchmaking — " .. (payload.modeLabel or payload.mode)
	statusLabel.Text = formatStatus(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = false
		showLobby()
	elseif state.phase == "arena" then
		gui.Enabled = false
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	gui.Enabled = false
	showLobby()
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
	showLobby()
end)
