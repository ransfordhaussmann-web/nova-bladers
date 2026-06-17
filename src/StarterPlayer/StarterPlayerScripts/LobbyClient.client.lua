local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hubHud = nil
local statsLabel = nil
local modeLabel = nil
local leaderboardLabel = nil

local function hideOthers()
	local hud = playerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
	local mobile = playerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

local function ensureHubHud()
	if hubHud then
		return
	end

	hubHud = Instance.new("ScreenGui")
	hubHud.Name = "HubHUD"
	hubHud.ResetOnSpawn = false
	hubHud.DisplayOrder = 3
	hubHud.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.fromOffset(16, 16)
	panel.Size = UDim2.fromOffset(260, 200)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = hubHud

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 28)
	title.Position = UDim2.fromOffset(8, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(120, 180, 255)
	title.Text = "Nova Hub"
	title.Parent = panel

	statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(1, -16, 0, 54)
	statsLabel.Position = UDim2.fromOffset(8, 36)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 15
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.TextColor3 = Color3.fromRGB(220, 225, 240)
	statsLabel.Text = ""
	statsLabel.Parent = panel

	modeLabel = Instance.new("TextLabel")
	modeLabel.Size = UDim2.new(1, -16, 0, 22)
	modeLabel.Position = UDim2.fromOffset(8, 92)
	modeLabel.BackgroundTransparency = 1
	modeLabel.Font = Enum.Font.GothamMedium
	modeLabel.TextSize = 14
	modeLabel.TextXAlignment = Enum.TextXAlignment.Left
	modeLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
	modeLabel.Text = ""
	modeLabel.Parent = panel

	leaderboardLabel = Instance.new("TextLabel")
	leaderboardLabel.Size = UDim2.new(1, -16, 0, 72)
	leaderboardLabel.Position = UDim2.fromOffset(8, 118)
	leaderboardLabel.BackgroundTransparency = 1
	leaderboardLabel.Font = Enum.Font.Gotham
	leaderboardLabel.TextSize = 13
	leaderboardLabel.TextXAlignment = Enum.TextXAlignment.Left
	leaderboardLabel.TextYAlignment = Enum.TextYAlignment.Top
	leaderboardLabel.TextColor3 = Color3.fromRGB(200, 205, 220)
	leaderboardLabel.Text = ""
	leaderboardLabel.Parent = panel
end

local function updateLeaderboardText(entries)
	local lines = { "Top Spieler:" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function showHubHud(payload)
	ensureHubHud()
	hideOthers()

	statsLabel.Text = string.format("Wins: %d\nLosses: %d\nRank: %d", payload.wins, payload.losses, payload.rank)
	modeLabel.Text = payload.modeLabel or "Modus: Training"
	leaderboardLabel.Text = updateLeaderboardText(payload.leaderboard or {})

	hubHud.Enabled = true

	local legacyLobby = playerGui:FindFirstChild("Lobby")
	if legacyLobby then
		legacyLobby.Enabled = false
	end
end

local function showLegacyLobby(payload)
	local gui = playerGui:WaitForChild("Lobby")
	local panel = gui:WaitForChild("Panel")

	hideOthers()
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins,
		payload.losses,
		payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"

	if panel:FindFirstChild("LeaderboardLabel") and payload.leaderboard then
		panel.LeaderboardLabel.Text = updateLeaderboardText(payload.leaderboard)
	end

	gui.Enabled = true
	if hubHud then
		hubHud.Enabled = false
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.hubMode then
		showHubHud(payload)
	else
		showLegacyLobby(payload)
	end
end)

-- Legacy fullscreen Start-Button (falls altes Lobby-GUI noch genutzt wird)
task.defer(function()
	local gui = playerGui:FindFirstChild("Lobby")
	if not gui then
		return
	end
	local panel = gui:FindFirstChild("Panel")
	local startButton = panel and panel:FindFirstChild("StartButton")
	if startButton then
		startButton.MouseButton1Click:Connect(function()
			gui.Enabled = false
			Remotes.EnterArena:FireServer()
		end)
	end
end)
