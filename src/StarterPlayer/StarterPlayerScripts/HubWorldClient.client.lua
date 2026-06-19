local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hallGui = Instance.new("ScreenGui")
hallGui.Name = "HallOfFame"
hallGui.ResetOnSpawn = false
hallGui.Enabled = false
hallGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(320, 280)
panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
panel.BorderSizePixel = 0
panel.Parent = hallGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 36)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.Text = "Ruhmeshalle"
title.TextColor3 = Color3.fromRGB(255, 210, 80)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "StatsLabel"
statsLabel.Size = UDim2.new(1, -20, 0, 80)
statsLabel.Position = UDim2.fromOffset(10, 48)
statsLabel.BackgroundTransparency = 1
statsLabel.TextColor3 = Color3.new(1, 1, 1)
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 18
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Parent = panel

local leaderboardLabel = Instance.new("TextLabel")
leaderboardLabel.Name = "LeaderboardLabel"
leaderboardLabel.Size = UDim2.new(1, -20, 0, 120)
leaderboardLabel.Position = UDim2.fromOffset(10, 132)
leaderboardLabel.BackgroundTransparency = 1
leaderboardLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
leaderboardLabel.Font = Enum.Font.Gotham
leaderboardLabel.TextSize = 16
leaderboardLabel.TextXAlignment = Enum.TextXAlignment.Left
leaderboardLabel.TextYAlignment = Enum.TextYAlignment.Top
leaderboardLabel.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(1, -20, 0, 36)
closeButton.Position = UDim2.new(0, 10, 1, -46)
closeButton.BackgroundColor3 = Color3.fromRGB(50, 56, 72)
closeButton.Text = "Schließen"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

local function formatLeaderboard(entries)
	local lines = { "Top Spieler:" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function showHallOfFame(payload)
	statsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins or 0,
		payload.losses or 0,
		payload.rank or 0
	)
	leaderboardLabel.Text = formatLeaderboard(payload.leaderboard or {})
	hallGui.Enabled = true
end

closeButton.MouseButton1Click:Connect(function()
	hallGui.Enabled = false
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.showHallOfFame then
		showHallOfFame(payload)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local beySelect = player.PlayerGui:FindFirstChild("BeySelect")
	if beySelect then
		beySelect.Enabled = true
	end
end)
