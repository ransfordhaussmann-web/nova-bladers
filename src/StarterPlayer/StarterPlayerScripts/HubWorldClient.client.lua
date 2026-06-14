local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function isHubWorld()
	return Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME) ~= nil
end

local function getOrCreateStatsGui()
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
	frame.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Statistiken"
	title.Parent = frame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.BackgroundTransparency = 1
	statsLabel.Position = UDim2.fromOffset(12, 40)
	statsLabel.Size = UDim2.new(1, -24, 0, 72)
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 16
	statsLabel.TextColor3 = Color3.new(1, 1, 1)
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Text = ""
	statsLabel.Parent = frame

	local modeLabel = Instance.new("TextLabel")
	modeLabel.Name = "ModeLabel"
	modeLabel.BackgroundTransparency = 1
	modeLabel.Position = UDim2.fromOffset(12, 112)
	modeLabel.Size = UDim2.new(1, -24, 0, 24)
	modeLabel.Font = Enum.Font.Gotham
	modeLabel.TextSize = 14
	modeLabel.TextColor3 = Color3.fromRGB(160, 200, 255)
	modeLabel.TextXAlignment = Enum.TextXAlignment.Left
	modeLabel.Text = ""
	modeLabel.Parent = frame

	local leaderboardLabel = Instance.new("TextLabel")
	leaderboardLabel.Name = "LeaderboardLabel"
	leaderboardLabel.BackgroundTransparency = 1
	leaderboardLabel.Position = UDim2.fromOffset(12, 140)
	leaderboardLabel.Size = UDim2.new(1, -24, 0, 100)
	leaderboardLabel.Font = Enum.Font.Gotham
	leaderboardLabel.TextSize = 14
	leaderboardLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	leaderboardLabel.TextXAlignment = Enum.TextXAlignment.Left
	leaderboardLabel.TextYAlignment = Enum.TextYAlignment.Top
	leaderboardLabel.Text = ""
	leaderboardLabel.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -8, 0, 8)
	closeButton.Size = UDim2.fromOffset(28, 28)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 16
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Text = "X"
	closeButton.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		gui.Enabled = false
	end)

	return gui
end

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

local function showStatsOverlay(payload)
	local gui = getOrCreateStatsGui()
	local panel = gui.Panel

	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRang: %d",
		payload.wins,
		payload.losses,
		payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	panel.LeaderboardLabel.Text = formatLeaderboard(payload.leaderboard or {})
	gui.Enabled = true
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	if not isHubWorld() then
		return
	end

	hideBattleUi()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end

	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if not isHubWorld() then
		return
	end

	hideBattleUi()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end

	if player:GetAttribute("InArena") ~= true and payload.showOverlay then
		showStatsOverlay(payload)
	end
end)

-- Hub-Hinweis beim Betreten
task.spawn(function()
	Workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if not isHubWorld() then
		return
	end

	local hint = player.PlayerGui:FindFirstChild("HubHint")
	if hint then
		return
	end

	hint = Instance.new("ScreenGui")
	hint.Name = "HubHint"
	hint.ResetOnSpawn = false
	hint.Parent = player.PlayerGui

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.fromOffset(420, 36)
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "Laufe zu den Zonen: Arena | Bey Shop | Statistiken"
	label.Parent = hint

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	task.delay(6, function()
		if hint and hint.Parent then
			hint:Destroy()
		end
	end)
end)
