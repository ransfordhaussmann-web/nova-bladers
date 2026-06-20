local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function setGuiEnabled(name, enabled)
	local gui = player.PlayerGui:FindFirstChild(name)
	if gui then
		gui.Enabled = enabled
	end
end

local function hideBattleUIs()
	setGuiEnabled("BattleHUD", false)
	setGuiEnabled("BeySelect", false)
	setGuiEnabled("MobileControls", false)
end

local function showLobbyPanel(payload)
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
	local panel = gui:WaitForChild("Panel")

	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"

	if panel:FindFirstChild("LeaderboardLabel") and payload.leaderboard then
		local lines = { "🏆 Top Spieler:" }
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	end

	gui.Enabled = true
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideBattleUIs()
	setGuiEnabled("Lobby", false)
end)

Remotes.ShowHallPanel.OnClientEvent:Connect(function(payload)
	showLobbyPanel(payload)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUIs()
	setGuiEnabled("Lobby", false)
	setGuiEnabled("BeySelect", true)
end)

local hub = workspace:WaitForChild("NovaHub", 30)
if hub then
	local hint = Instance.new("ScreenGui")
	hint.Name = "HubHint"
	hint.ResetOnSpawn = false
	hint.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.new(0, 520, 0, 36)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(220, 230, 255)
	label.TextSize = 16
	label.Text = "Willkommen im Nova Hub — laufe zu den Zonen (Arena, Bey-Labor, Ruhmeshalle)"
	label.Parent = hint

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end
