local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local statsGui

local function ensureStatsGui()
	if statsGui then return statsGui end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HubStatsOverlay"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

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
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.fromOffset(10, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 200, 60)
	title.TextSize = 22
	title.Text = "Ruhmeshalle"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Size = UDim2.new(1, -20, 0, 80)
	statsLabel.Position = UDim2.fromOffset(10, 50)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextColor3 = Color3.new(1, 1, 1)
	statsLabel.TextSize = 18
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Text = ""
	statsLabel.Parent = frame

	local leaderboardLabel = Instance.new("TextLabel")
	leaderboardLabel.Name = "LeaderboardLabel"
	leaderboardLabel.Size = UDim2.new(1, -20, 1, -140)
	leaderboardLabel.Position = UDim2.fromOffset(10, 130)
	leaderboardLabel.BackgroundTransparency = 1
	leaderboardLabel.Font = Enum.Font.Gotham
	leaderboardLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	leaderboardLabel.TextSize = 16
	leaderboardLabel.TextXAlignment = Enum.TextXAlignment.Left
	leaderboardLabel.TextYAlignment = Enum.TextYAlignment.Top
	leaderboardLabel.Text = ""
	leaderboardLabel.Parent = frame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.fromOffset(100, 32)
	closeBtn.Position = UDim2.new(0.5, -50, 1, -42)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextSize = 16
	closeBtn.Text = "Schließen"
	closeBtn.Parent = frame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		gui.Enabled = false
	end)

	statsGui = gui
	return gui
end

local function showStatsOverlay(payload)
	local gui = ensureStatsGui()
	local panel = gui.Panel
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins or 0, payload.losses or 0, payload.rank or 0
	)
	local lines = {"🏆 Top Spieler:"}
	for _, entry in payload.leaderboard or {} do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #(payload.leaderboard or {}) == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	gui.Enabled = true
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function connectZonePrompts()
	local hub = workspace:WaitForChild(HubConfig.HUB_NAME, 30)
	if not hub then return end
	local zones = hub:WaitForChild("Zones", 10)
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function()
				local zoneId = zonePart:GetAttribute("ZoneId")
				if zoneId then
					Remotes.HubZoneAction:FireServer(zoneId)
				end
			end)
		end
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.showStats then
		showStatsOverlay(payload)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	if statsGui then statsGui.Enabled = false end
end)

task.spawn(connectZonePrompts)
