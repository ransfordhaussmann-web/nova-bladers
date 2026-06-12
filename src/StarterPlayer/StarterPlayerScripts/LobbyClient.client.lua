local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function ensureHubStatsGui()
	local hubStats = player.PlayerGui:FindFirstChild("HubStats")
	if hubStats then return hubStats end

	hubStats = Instance.new("ScreenGui")
	hubStats.Name = "HubStats"
	hubStats.ResetOnSpawn = false
	hubStats.DisplayOrder = 4
	hubStats.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.new(0, 12, 0, 12)
	frame.Size = UDim2.new(0, 200, 0, 110)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.2
	frame.Parent = hubStats

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stats = Instance.new("TextLabel")
	stats.Name = "StatsLabel"
	stats.Size = UDim2.new(1, -12, 0.55, 0)
	stats.Position = UDim2.new(0, 6, 0, 6)
	stats.BackgroundTransparency = 1
	stats.Font = Enum.Font.Gotham
	stats.TextColor3 = Color3.new(1, 1, 1)
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.TextSize = 14
	stats.Text = ""
	stats.Parent = frame

	local mode = Instance.new("TextLabel")
	mode.Name = "ModeLabel"
	mode.Size = UDim2.new(1, -12, 0.35, 0)
	mode.Position = UDim2.new(0, 6, 0.6, 0)
	mode.BackgroundTransparency = 1
	mode.Font = Enum.Font.GothamMedium
	mode.TextColor3 = Color3.fromRGB(120, 200, 255)
	mode.TextXAlignment = Enum.TextXAlignment.Left
	mode.TextSize = 13
	mode.Text = ""
	mode.Parent = frame

	return hubStats
end

local function updateStatsLabels(statsLabel, modeLabel, payload)
	statsLabel.Text = string.format("Wins: %d\nLosses: %d\nRank: %d", payload.wins, payload.losses, payload.rank)
	modeLabel.Text = payload.modeLabel or "Modus: Training"
end

local function updateLeaderboardLabel(payload)
	if not panel:FindFirstChild("LeaderboardLabel") or not payload.leaderboard then return end
	local lines = {"🏆 Top Spieler:"}
	for _, entry in payload.leaderboard do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #payload.leaderboard == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	panel.LeaderboardLabel.Text = table.concat(lines, "\n")
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	updateStatsLabels(panel.StatsLabel, panel.ModeLabel, payload)
	updateLeaderboardLabel(payload)

	if payload.hubMode then
		gui.Enabled = false
		local hubStats = ensureHubStatsGui()
		updateStatsLabels(hubStats.Panel.StatsLabel, hubStats.Panel.ModeLabel, payload)
		hubStats.Enabled = true
	else
		local hubStats = player.PlayerGui:FindFirstChild("HubStats")
		if hubStats then hubStats.Enabled = false end
		gui.Enabled = true
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
	Remotes.EnterArena:FireServer()
end)
