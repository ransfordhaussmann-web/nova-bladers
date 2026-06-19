local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local statsGui

local function ensureStatsGui()
	if statsGui then
		return statsGui
	end

	statsGui = Instance.new("ScreenGui")
	statsGui.Name = "HubStatsOverlay"
	statsGui.ResetOnSpawn = false
	statsGui.Enabled = false
	statsGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -16, 0, 16)
	frame.Size = UDim2.fromOffset(220, 120)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = statsGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = frame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Size = UDim2.new(1, 0, 0, 50)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 14
	statsLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Text = ""
	statsLabel.Parent = frame

	local modeLabel = Instance.new("TextLabel")
	modeLabel.Name = "ModeLabel"
	modeLabel.Position = UDim2.new(0, 0, 0, 54)
	modeLabel.Size = UDim2.new(1, 0, 0, 20)
	modeLabel.BackgroundTransparency = 1
	modeLabel.Font = Enum.Font.GothamBold
	modeLabel.TextSize = 13
	modeLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
	modeLabel.TextXAlignment = Enum.TextXAlignment.Left
	modeLabel.Text = ""
	modeLabel.Parent = frame

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HintLabel"
	hintLabel.Position = UDim2.new(0, 0, 0, 78)
	hintLabel.Size = UDim2.new(1, 0, 0, 32)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextSize = 11
	hintLabel.TextColor3 = Color3.fromRGB(160, 165, 180)
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.TextYAlignment = Enum.TextYAlignment.Top
	hintLabel.TextWrapped = true
	hintLabel.Text = "Laufe zu den Zonen: Arena, Bey-Labor, Ruhmeshalle"
	hintLabel.Parent = frame

	return statsGui
end

local function showStatsOverlay(payload)
	local gui = ensureStatsGui()
	gui.Panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	gui.Panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	gui.Enabled = true
end

local function showLeaderboardPopup(payload)
	local popup = playerGui:FindFirstChild("HubLeaderboardPopup")
	if popup then
		popup:Destroy()
	end

	popup = Instance.new("ScreenGui")
	popup.Name = "HubLeaderboardPopup"
	popup.ResetOnSpawn = false
	popup.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(280, 320)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BorderSizePixel = 0
	frame.Parent = popup

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Ruhmeshalle"
	title.Parent = frame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Position = UDim2.fromOffset(10, 48)
	statsLabel.Size = UDim2.new(1, -20, 0, 60)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 14
	statsLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Text = string.format(
		"Deine Stats\nWins: %d  Losses: %d  Rank: %d",
		payload.wins, payload.losses, payload.rank
	)
	statsLabel.Parent = frame

	local boardLabel = Instance.new("TextLabel")
	boardLabel.Position = UDim2.fromOffset(10, 118)
	boardLabel.Size = UDim2.new(1, -20, 1, -170)
	boardLabel.BackgroundTransparency = 1
	boardLabel.Font = Enum.Font.Gotham
	boardLabel.TextSize = 14
	boardLabel.TextColor3 = Color3.fromRGB(200, 205, 220)
	boardLabel.TextXAlignment = Enum.TextXAlignment.Left
	boardLabel.TextYAlignment = Enum.TextYAlignment.Top
	boardLabel.TextWrapped = true

	local lines = {"Top Spieler:"}
	if payload.leaderboard then
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
	end
	boardLabel.Text = table.concat(lines, "\n")
	boardLabel.Parent = frame

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -12)
	close.Size = UDim2.fromOffset(120, 32)
	close.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 14
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "Schließen"
	close.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = close

	close.MouseButton1Click:Connect(function()
		popup:Destroy()
	end)
end

Remotes.HubZoneAction.OnClientEvent:Connect(function(action, payload)
	if action == "ShowStats" then
		showLeaderboardPopup(payload)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.hubMode then
		showStatsOverlay(payload)
	end
end)
