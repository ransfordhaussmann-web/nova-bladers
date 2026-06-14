local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inArena = false
local statsGui

local function ensureStatsGui()
	if statsGui then
		return statsGui
	end

	local playerGui = player:WaitForChild("PlayerGui")
	statsGui = Instance.new("ScreenGui")
	statsGui.Name = "HubStatsOverlay"
	statsGui.ResetOnSpawn = false
	statsGui.Enabled = false
	statsGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 12)
	frame.Size = UDim2.fromOffset(280, 90)
	frame.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
	frame.BackgroundTransparency = 0.15
	frame.Parent = statsGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.BackgroundTransparency = 1
	statsLabel.Position = UDim2.fromOffset(12, 8)
	statsLabel.Size = UDim2.new(1, -24, 0, 36)
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 16
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextColor3 = Color3.new(1, 1, 1)
	statsLabel.Text = "Wins: 0 | Losses: 0"
	statsLabel.Parent = frame

	local modeLabel = Instance.new("TextLabel")
	modeLabel.Name = "ModeLabel"
	modeLabel.BackgroundTransparency = 1
	modeLabel.Position = UDim2.fromOffset(12, 44)
	modeLabel.Size = UDim2.new(1, -24, 0, 20)
	modeLabel.Font = Enum.Font.Gotham
	modeLabel.TextSize = 14
	modeLabel.TextXAlignment = Enum.TextXAlignment.Left
	modeLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
	modeLabel.Text = "Modus: Training"
	modeLabel.Parent = frame

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HintLabel"
	hintLabel.BackgroundTransparency = 1
	hintLabel.Position = UDim2.fromOffset(12, 66)
	hintLabel.Size = UDim2.new(1, -24, 0, 18)
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextSize = 12
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
	hintLabel.Text = "Laufe zu den Zonen: Arena, Shop, Ruhmeshalle"
	hintLabel.Parent = frame

	return statsGui
end

local function updateHubOverlay(payload)
	local gui = ensureStatsGui()
	gui.Panel.StatsLabel.Text = string.format(
		"Wins: %d  |  Losses: %d  |  Rank: %d",
		payload.wins or 0,
		payload.losses or 0,
		payload.rank or 0
	)
	gui.Panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	gui.Enabled = not inArena
end

Remotes.HubState.OnClientEvent:Connect(function(state)
	inArena = state.inArena == true
	if statsGui then
		statsGui.Enabled = not inArena
	end

	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = not inArena
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if not inArena and payload.inHub ~= false then
		updateHubOverlay(payload)
	end
end)

local function ensureLeaderboardPopup()
	local playerGui = player:WaitForChild("PlayerGui")
	local popup = playerGui:FindFirstChild("HubLeaderboardPopup")
	if popup then
		return popup
	end

	popup = Instance.new("ScreenGui")
	popup.Name = "HubLeaderboardPopup"
	popup.ResetOnSpawn = false
	popup.Enabled = false
	popup.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(320, 280)
	frame.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
	frame.BackgroundTransparency = 0.1
	frame.Parent = popup

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -32, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "Ruhmeshalle"
	title.Parent = frame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.BackgroundTransparency = 1
	statsLabel.Position = UDim2.fromOffset(16, 44)
	statsLabel.Size = UDim2.new(1, -32, 0, 48)
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 15
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	statsLabel.Text = ""
	statsLabel.Parent = frame

	local boardLabel = Instance.new("TextLabel")
	boardLabel.Name = "LeaderboardLabel"
	boardLabel.BackgroundTransparency = 1
	boardLabel.Position = UDim2.fromOffset(16, 100)
	boardLabel.Size = UDim2.new(1, -32, 1, -148)
	boardLabel.Font = Enum.Font.Gotham
	boardLabel.TextSize = 15
	boardLabel.TextXAlignment = Enum.TextXAlignment.Left
	boardLabel.TextYAlignment = Enum.TextYAlignment.Top
	boardLabel.TextColor3 = Color3.new(1, 1, 1)
	boardLabel.Text = ""
	boardLabel.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(0.5, 1)
	closeButton.Position = UDim2.new(0.5, 0, 1, -12)
	closeButton.Size = UDim2.fromOffset(120, 32)
	closeButton.BackgroundColor3 = Color3.fromRGB(70, 120, 220)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 14
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Text = "Schließen"
	closeButton.Parent = frame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		popup.Enabled = false
	end)

	return popup
end

Remotes.RefreshHubStats.OnClientEvent:Connect(function(payload)
	local popup = ensureLeaderboardPopup()
	popup.Panel.StatsLabel.Text = string.format(
		"Deine Stats\nWins: %d  |  Losses: %d  |  Rank: %d",
		payload.wins or 0,
		payload.losses or 0,
		payload.rank or 0
	)

	local lines = {"🏆 Top Spieler:"}
	if payload.leaderboard then
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
	end
	if not payload.leaderboard or #payload.leaderboard == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	popup.Panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	popup.Enabled = true
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
