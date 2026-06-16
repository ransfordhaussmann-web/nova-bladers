local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers:WaitForChild("HubConfig"))
local Remotes = NovaBladers:WaitForChild("Remotes")

if not HubConfig.USE_3D_HUB then
	return
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

local function getOrCreateHud()
	local gui = player.PlayerGui:FindFirstChild("HubHUD")
	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "StatsPanel"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(12, 12)
	frame.Size = UDim2.fromOffset(220, 120)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(120, 200, 255)
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Nova Bladers"
	title.Parent = frame

	local stats = Instance.new("TextLabel")
	stats.Name = "StatsLabel"
	stats.LayoutOrder = 2
	stats.Size = UDim2.new(1, 0, 0, 44)
	stats.BackgroundTransparency = 1
	stats.Font = Enum.Font.Gotham
	stats.TextColor3 = Color3.new(1, 1, 1)
	stats.TextSize = 14
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.Text = ""
	stats.Parent = frame

	local mode = Instance.new("TextLabel")
	mode.Name = "ModeLabel"
	mode.LayoutOrder = 3
	mode.Size = UDim2.new(1, 0, 0, 18)
	mode.BackgroundTransparency = 1
	mode.Font = Enum.Font.Gotham
	mode.TextColor3 = Color3.fromRGB(180, 190, 210)
	mode.TextSize = 13
	mode.TextXAlignment = Enum.TextXAlignment.Left
	mode.Text = ""
	mode.Parent = frame

	return gui
end

local function updateStats(payload)
	local gui = getOrCreateHud()
	gui.Enabled = true
	local panel = gui.StatsPanel
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins,
		payload.losses,
		payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
end

local function showLeaderboardPopup(entries)
	local gui = player.PlayerGui:FindFirstChild("HubLeaderboard")
	if gui then
		gui:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubLeaderboard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(280, 260)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 200, 60)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Top Spieler"
	title.Parent = frame

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end

	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -20, 1, -90)
	body.Position = UDim2.fromOffset(10, 48)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextSize = 16
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = table.concat(lines, "\n")
	body.Parent = frame

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(1, -20, 0, 36)
	close.Position = UDim2.new(0, 10, 1, -46)
	close.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
	close.Font = Enum.Font.GothamBold
	close.TextColor3 = Color3.new(1, 1, 1)
	close.TextSize = 16
	close.Text = "Schließen"
	close.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = close

	close.MouseButton1Click:Connect(function()
		gui:Destroy()
	end)
end

local function openBeySelect()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local legacyLobby = player.PlayerGui:FindFirstChild("Lobby")
if legacyLobby then
	legacyLobby.Enabled = false
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideBattleUi()
	updateStats(payload)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUi()
	openBeySelect()
end)

Remotes.ShowLeaderboard.OnClientEvent:Connect(showLeaderboardPopup)
