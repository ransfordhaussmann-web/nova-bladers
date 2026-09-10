local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

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
statusLabel.Text = ""
statusLabel.Parent = panel

local playersLabel = Instance.new("TextLabel")
playersLabel.Name = "PlayersLabel"
playersLabel.Size = UDim2.new(1, -16, 0, 40)
playersLabel.Position = UDim2.fromOffset(8, 80)
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

local function formatStatus(payload)
	if payload.status == "pending" then
		return MatchmakingConfig.PENDING_LABEL
	end
	if payload.status == "filling" and payload.fillRemaining then
		return string.format("Spieler gefunden — Start in %ds", payload.fillRemaining)
	end
	if payload.count < payload.minPlayers then
		return string.format(
			"%s\n%s / %d Spieler",
			MatchmakingConfig.MAX_WAIT_LABEL,
			payload.count,
			payload.minPlayers
		)
	end
	return string.format("%d / %d Spieler bereit", payload.count, payload.maxPlayers)
end

local function applyQueueUpdate(payload)
	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = string.format("Warteschlange — %s", payload.label or "Arena")
	statusLabel.Text = formatStatus(payload)

	local lines = {}
	for _, name in payload.playerNames or {} do
		table.insert(lines, "• " .. name)
	end
	playersLabel.Text = table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueUpdate)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		gui.Enabled = false
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)
