local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function getOrCreateHubHud()
	local gui = player:WaitForChild("PlayerGui"):FindFirstChild("HubHud")
	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubHud"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "CompactPanel"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(12, 12)
	frame.Size = UDim2.fromOffset(220, 120)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "TitleLabel"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(10, 6)
	title.Size = UDim2.new(1, -20, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.Text = "Nova Hub"
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local modeLabel = Instance.new("TextLabel")
	modeLabel.Name = "ModeLabel"
	modeLabel.BackgroundTransparency = 1
	modeLabel.Position = UDim2.fromOffset(10, 30)
	modeLabel.Size = UDim2.new(1, -20, 0, 18)
	modeLabel.Font = Enum.Font.Gotham
	modeLabel.Text = "Modus: Training"
	modeLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	modeLabel.TextSize = 13
	modeLabel.TextXAlignment = Enum.TextXAlignment.Left
	modeLabel.Parent = frame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.BackgroundTransparency = 1
	statsLabel.Position = UDim2.fromOffset(10, 52)
	statsLabel.Size = UDim2.new(1, -20, 0, 54)
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.Text = "Wins: 0\nLosses: 0\nRank: 0"
	statsLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
	statsLabel.TextSize = 13
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Parent = frame

	return gui
end

local function getOrCreateStatsOverlay()
	local gui = player.PlayerGui:FindFirstChild("HubStatsOverlay")
	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubStatsOverlay"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(320, 280)
	frame.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "TitleLabel"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -32, 0, 24)
	title.Font = Enum.Font.GothamBold
	title.Text = "Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 210, 90)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.BackgroundTransparency = 1
	statsLabel.Position = UDim2.fromOffset(16, 44)
	statsLabel.Size = UDim2.new(1, -32, 0, 72)
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.Text = ""
	statsLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
	statsLabel.TextSize = 15
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Parent = frame

	local leaderboardLabel = Instance.new("TextLabel")
	leaderboardLabel.Name = "LeaderboardLabel"
	leaderboardLabel.BackgroundTransparency = 1
	leaderboardLabel.Position = UDim2.fromOffset(16, 120)
	leaderboardLabel.Size = UDim2.new(1, -32, 1, -136)
	leaderboardLabel.Font = Enum.Font.Gotham
	leaderboardLabel.Text = ""
	leaderboardLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	leaderboardLabel.TextSize = 14
	leaderboardLabel.TextXAlignment = Enum.TextXAlignment.Left
	leaderboardLabel.TextYAlignment = Enum.TextYAlignment.Top
	leaderboardLabel.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 12)
	closeButton.Size = UDim2.fromOffset(28, 28)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 68, 82)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextSize = 14
	closeButton.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		gui.Enabled = false
	end)

	return gui
end

local hubHud = getOrCreateHubHud()
local statsOverlay = getOrCreateStatsOverlay()
local compactPanel = hubHud.CompactPanel

local function formatLeaderboard(entries)
	local lines = {"Top Spieler:"}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Eintraege")
	end
	return table.concat(lines, "\n")
end

local function applyLobbyPayload(payload)
	compactPanel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	compactPanel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)

	if payload.leaderboard then
		local panel = statsOverlay.Panel
		panel.StatsLabel.Text = string.format(
			"Wins: %d\nLosses: %d\nRank: %d",
			payload.wins, payload.losses, payload.rank
		)
		panel.LeaderboardLabel.Text = formatLeaderboard(payload.leaderboard)
	end
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function showHubUi()
	local legacyLobby = player.PlayerGui:FindFirstChild("Lobby")
	if legacyLobby then
		legacyLobby.Enabled = false
	end
	hideBattleUi()
	hubHud.Enabled = true
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.hubMode then
		showHubUi()
		applyLobbyPayload(payload)
		return
	end

	local legacyLobby = player.PlayerGui:FindFirstChild("Lobby")
	if legacyLobby then
		local panel = legacyLobby:FindFirstChild("Panel")
		if panel then
			panel.StatsLabel.Text = string.format(
				"Wins: %d\nLosses: %d\nRank: %d",
				payload.wins, payload.losses, payload.rank
			)
			panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
			if panel:FindFirstChild("LeaderboardLabel") and payload.leaderboard then
				panel.LeaderboardLabel.Text = formatLeaderboard(payload.leaderboard)
			end
		end
		legacyLobby.Enabled = true
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.HubZoneAction.OnClientEvent:Connect(function(action, payload)
	if action == "ShowStats" and payload then
		applyLobbyPayload(payload)
		statsOverlay.Enabled = true
	end
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	hubHud.Enabled = false
	statsOverlay.Enabled = false
	local legacyLobby = player.PlayerGui:FindFirstChild("Lobby")
	if legacyLobby then
		legacyLobby.Enabled = false
	end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
end)

showHubUi()
