local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local statsGui
local inHub = true

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function formatStats(payload)
	local lines = {
		string.format("Wins: %d  Losses: %d", payload.wins, payload.losses),
		string.format("Rangpunkte: %d", payload.rank),
		payload.modeLabel or "Modus: Training",
		"",
		"Top Spieler:",
	}
	for _, entry in payload.leaderboard or {} do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if not payload.leaderboard or #payload.leaderboard == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

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
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -32, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(120, 220, 160)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Statistik-Tafel"
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(16, 48)
	body.Size = UDim2.new(1, -32, 1, -96)
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextSize = 16
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Parent = frame

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -12)
	close.Size = UDim2.fromOffset(120, 32)
	close.BackgroundColor3 = Color3.fromRGB(70, 200, 120)
	close.Font = Enum.Font.GothamBold
	close.TextColor3 = Color3.new(1, 1, 1)
	close.TextSize = 16
	close.Text = "Schließen"
	close.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = close

	close.MouseButton1Click:Connect(function()
		gui.Enabled = false
	end)

	statsGui = gui
	return gui
end

local function showStats(payload)
	local gui = ensureStatsGui()
	gui.Panel.Body.Text = formatStats(payload)
	gui.Enabled = true
end

local function setHubMode(enabled)
	inHub = enabled
	hideBattleUi()

	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = not enabled
	end

	local beySelect = player.PlayerGui:FindFirstChild("BeySelect")
	if beySelect and enabled then
		beySelect.Enabled = false
	end
end

Remotes.HubState.OnClientEvent:Connect(function(state)
	setHubMode(state.location == "hub")
end)

Remotes.RefreshHubStats.OnClientEvent:Connect(function(payload)
	if inHub then
		showStats(payload)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	if not inHub then return end
	local beySelect = player.PlayerGui:FindFirstChild("BeySelect")
	if beySelect then
		beySelect.Enabled = true
	end
end)

-- Initial hub hint near spawn
task.defer(function()
	local hub = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 10)
	if not hub then return end
	local hint = Instance.new("BillboardGui")
	hint.Name = "HubHint"
	hint.Size = UDim2.fromOffset(260, 60)
	hint.StudsOffset = Vector3.new(0, 4, 0)
	hint.AlwaysOnTop = true
	hint.Parent = hub:FindFirstChild("HubSpawn") or hub

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.Text = "Laufe zu Arena, Bey-Shop oder Statistik-Tafel"
	label.Parent = hint
end)
