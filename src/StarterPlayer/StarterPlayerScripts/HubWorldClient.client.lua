local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HubOverlay"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Hud"
frame.AnchorPoint = Vector2.new(0, 0)
frame.Position = UDim2.fromOffset(16, 16)
frame.Size = UDim2.fromOffset(260, 150)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
frame.BackgroundTransparency = 0.25
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 22)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(120, 200, 255)
title.Text = "Nova Hub"
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.BackgroundTransparency = 1
hint.Position = UDim2.fromOffset(12, 32)
hint.Size = UDim2.new(1, -24, 0, 44)
hint.Font = Enum.Font.Gotham
hint.TextSize = 13
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextYAlignment = Enum.TextYAlignment.Top
hint.TextWrapped = true
hint.TextColor3 = Color3.fromRGB(210, 215, 230)
hint.Text = "Laufe zu Arena-Tor, Bey-Shop oder Ruhmeshalle."
hint.Parent = frame

local stats = Instance.new("TextLabel")
stats.Name = "Stats"
stats.BackgroundTransparency = 1
stats.Position = UDim2.fromOffset(12, 78)
stats.Size = UDim2.new(1, -24, 0, 58)
stats.Font = Enum.Font.Gotham
stats.TextSize = 13
stats.TextXAlignment = Enum.TextXAlignment.Left
stats.TextYAlignment = Enum.TextYAlignment.Top
stats.TextWrapped = true
stats.TextColor3 = Color3.fromRGB(230, 230, 240)
stats.Text = "Wins: 0 | Losses: 0"
stats.Parent = frame

local function setVisible(visible)
	screenGui.Enabled = visible
end

local function updateStats(payload)
	stats.Text = string.format(
		"Wins: %d | Losses: %d | Rank: %d\n%s",
		payload.wins or 0,
		payload.losses or 0,
		payload.rank or 0,
		payload.modeLabel or ""
	)
end

Remotes.HubState.OnClientEvent:Connect(function(state)
	inHub = state.inHub == true
	setVisible(inHub)
end)

Remotes.RefreshHubStats.OnClientEvent:Connect(function(payload)
	updateStats(payload)
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	updateStats(payload)
end)

setVisible(inHub)
