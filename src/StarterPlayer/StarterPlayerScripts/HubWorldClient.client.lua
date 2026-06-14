local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true

local function getOrCreateHud()
	local gui = player.PlayerGui:FindFirstChild("HubHUD")
	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubHUD"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.fromOffset(260, 200)
	frame.Position = UDim2.new(0, 12, 0, 12)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "TitleLabel"
	title.Size = UDim2.new(1, 0, 0, 22)
	title.BackgroundTransparency = 1
	title.Text = "Nova Hub"
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.LayoutOrder = 1
	title.Parent = frame

	local mode = Instance.new("TextLabel")
	mode.Name = "ModeLabel"
	mode.Size = UDim2.new(1, 0, 0, 18)
	mode.BackgroundTransparency = 1
	mode.Text = "Modus: Training"
	mode.TextColor3 = Color3.fromRGB(200, 210, 230)
	mode.TextXAlignment = Enum.TextXAlignment.Left
	mode.Font = Enum.Font.Gotham
	mode.TextSize = 14
	mode.LayoutOrder = 2
	mode.Parent = frame

	local stats = Instance.new("TextLabel")
	stats.Name = "StatsLabel"
	stats.Size = UDim2.new(1, 0, 0, 54)
	stats.BackgroundTransparency = 1
	stats.Text = "Wins: 0\nLosses: 0\nRank: 0"
	stats.TextColor3 = Color3.fromRGB(220, 225, 240)
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.Font = Enum.Font.Gotham
	stats.TextSize = 14
	stats.LayoutOrder = 3
	stats.Parent = frame

	local leaderboard = Instance.new("TextLabel")
	leaderboard.Name = "LeaderboardLabel"
	leaderboard.Size = UDim2.new(1, 0, 0, 72)
	leaderboard.BackgroundTransparency = 1
	leaderboard.Text = "🏆 Top Spieler:\nNoch keine Einträge"
	leaderboard.TextColor3 = Color3.fromRGB(180, 190, 210)
	leaderboard.TextXAlignment = Enum.TextXAlignment.Left
	leaderboard.TextYAlignment = Enum.TextYAlignment.Top
	leaderboard.Font = Enum.Font.Gotham
	leaderboard.TextSize = 13
	leaderboard.LayoutOrder = 4
	leaderboard.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "HintLabel"
	hint.Size = UDim2.new(1, 0, 0, 32)
	hint.BackgroundTransparency = 1
	hint.Text = "Laufe zu den Zonen: Arena, Shop, Stats"
	hint.TextColor3 = Color3.fromRGB(140, 150, 170)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextWrapped = true
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 12
	hint.LayoutOrder = 5
	hint.Parent = frame

	return gui
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

local function updateHud(payload)
	local gui = getOrCreateHud()
	local panel = gui.Panel

	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins,
		payload.losses,
		payload.rank
	)

	if payload.leaderboard then
		local lines = { "🏆 Top Spieler:" }
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	end

	gui.Enabled = inHub
end

Remotes.HubState.OnClientEvent:Connect(function(state)
	inHub = state.inHub == true
	local gui = player.PlayerGui:FindFirstChild("HubHUD")
	if gui then
		gui.Enabled = inHub
	end
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby and inHub then
		lobby.Enabled = false
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.hubMode then
		hideBattleUi()
		updateHud(payload)
		return
	end

	local gui = player.PlayerGui:FindFirstChild("HubHUD")
	if gui then
		gui.Enabled = false
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
