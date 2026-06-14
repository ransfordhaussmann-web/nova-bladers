local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local cachedPayload = nil
local statsGui: ScreenGui? = nil

local function hideBattleUI()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

local function formatStats(payload): string
	local lines = {
		string.format("Wins: %d  |  Losses: %d  |  Rang: %d", payload.wins, payload.losses, payload.rank),
		"",
		payload.modeLabel or "Modus: Training",
		"",
		"🏆 Top Spieler:",
	}
	if payload.leaderboard and #payload.leaderboard > 0 then
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
	else
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function showStatsPopup(payload)
	hideBattleUI()

	if not statsGui then
		statsGui = Instance.new("ScreenGui")
		statsGui.Name = "HubStatsPopup"
		statsGui.ResetOnSpawn = false
		statsGui.Parent = player:WaitForChild("PlayerGui")

		local frame = Instance.new("Frame")
		frame.Name = "Panel"
		frame.Size = UDim2.fromOffset(320, 280)
		frame.Position = UDim2.new(0.5, -160, 0.5, -140)
		frame.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
		frame.BorderSizePixel = 0
		frame.Parent = statsGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, -20, 0, 36)
		title.Position = UDim2.fromOffset(10, 8)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 20
		title.TextColor3 = Color3.fromRGB(240, 200, 80)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "Ruhmeshalle"
		title.Parent = frame

		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.Size = UDim2.new(1, -20, 1, -90)
		body.Position = UDim2.fromOffset(10, 48)
		body.BackgroundTransparency = 1
		body.Font = Enum.Font.Gotham
		body.TextSize = 16
		body.TextColor3 = Color3.fromRGB(220, 220, 230)
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextWrapped = true
		body.Parent = frame

		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.Size = UDim2.new(1, -20, 0, 32)
		close.Position = UDim2.new(0, 10, 1, -42)
		close.BackgroundColor3 = Color3.fromRGB(70, 90, 140)
		close.Font = Enum.Font.GothamBold
		close.TextSize = 16
		close.TextColor3 = Color3.new(1, 1, 1)
		close.Text = "Schließen"
		close.Parent = frame

		local closeCorner = Instance.new("UICorner")
		closeCorner.CornerRadius = UDim.new(0, 6)
		closeCorner.Parent = close

		close.MouseButton1Click:Connect(function()
			statsGui.Enabled = false
		end)
	end

	statsGui.Panel.Body.Text = formatStats(payload)
	statsGui.Enabled = true
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	cachedPayload = payload
	hideBattleUI()
end)

Remotes.HubShowStats.OnClientEvent:Connect(function(payload)
	cachedPayload = payload
	showStatsPopup(payload)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUI()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.ArenaEntered.OnClientEvent:Connect(function()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
end)
