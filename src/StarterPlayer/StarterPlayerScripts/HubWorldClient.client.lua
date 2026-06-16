local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hubGui
local statsLabel
local modeLabel
local leaderboardLabel

local function ensureHubGui()
	if hubGui then return end

	hubGui = Instance.new("ScreenGui")
	hubGui.Name = "HubOverlay"
	hubGui.ResetOnSpawn = false
	hubGui.Enabled = false
	hubGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Hud"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.new(0, 12, 0, 12)
	frame.Size = UDim2.fromOffset(220, 160)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = hubGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Position = UDim2.fromOffset(10, 8)
	statsLabel.Size = UDim2.new(1, -20, 0, 50)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextColor3 = Color3.new(1, 1, 1)
	statsLabel.TextSize = 14
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Text = ""
	statsLabel.Parent = frame

	modeLabel = Instance.new("TextLabel")
	modeLabel.Name = "ModeLabel"
	modeLabel.Position = UDim2.fromOffset(10, 58)
	modeLabel.Size = UDim2.new(1, -20, 0, 20)
	modeLabel.BackgroundTransparency = 1
	modeLabel.Font = Enum.Font.GothamBold
	modeLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
	modeLabel.TextSize = 13
	modeLabel.TextXAlignment = Enum.TextXAlignment.Left
	modeLabel.Text = ""
	modeLabel.Parent = frame

	leaderboardLabel = Instance.new("TextLabel")
	leaderboardLabel.Name = "LeaderboardLabel"
	leaderboardLabel.Position = UDim2.fromOffset(10, 82)
	leaderboardLabel.Size = UDim2.new(1, -20, 1, -90)
	leaderboardLabel.BackgroundTransparency = 1
	leaderboardLabel.Font = Enum.Font.Gotham
	leaderboardLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	leaderboardLabel.TextSize = 12
	leaderboardLabel.TextXAlignment = Enum.TextXAlignment.Left
	leaderboardLabel.TextYAlignment = Enum.TextYAlignment.Top
	leaderboardLabel.Text = ""
	leaderboardLabel.Visible = false
	leaderboardLabel.Parent = frame
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
end

local function showHubOverlay(payload)
	ensureHubGui()
	statsLabel.Text = string.format("Wins: %d\nLosses: %d\nRank: %d", payload.wins, payload.losses, payload.rank)
	modeLabel.Text = payload.modeLabel or "Modus: Training"
	hubGui.Enabled = true
	hideBattleUi()
end

local function showLeaderboardOverlay(payload)
	ensureHubGui()
	local lines = {"🏆 Top Spieler:"}
	if payload and payload.leaderboard then
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
	else
		table.insert(lines, "Noch keine Einträge")
	end
	leaderboardLabel.Text = table.concat(lines, "\n")
	leaderboardLabel.Visible = true
	hubGui.Enabled = true
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if not HubConfig.USE_3D_HUB or not payload.use3DHub then return end
	showHubOverlay(payload)
end)

Remotes.ShowLeaderboard.OnClientEvent:Connect(function(payload)
	if not HubConfig.USE_3D_HUB then return end
	showLeaderboardOverlay(payload)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	if hubGui then hubGui.Enabled = false end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function(payload)
	if not HubConfig.USE_3D_HUB then return end
	if payload then
		showHubOverlay(payload)
	else
		ensureHubGui()
		hubGui.Enabled = true
		hideBattleUi()
	end
end)
