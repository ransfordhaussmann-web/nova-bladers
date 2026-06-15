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

local function applyHubLayout()
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.new(0, 16, 0, 16)
	panel.Size = UDim2.fromOffset(260, 220)

	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Visible = false
	end

	local hint = panel:FindFirstChild("HubHint")
	if not hint then
		hint = Instance.new("TextLabel")
		hint.Name = "HubHint"
		hint.Size = UDim2.new(1, -12, 0, 48)
		hint.Position = UDim2.new(0, 6, 1, -54)
		hint.BackgroundTransparency = 1
		hint.Font = Enum.Font.Gotham
		hint.TextColor3 = Color3.fromRGB(180, 200, 230)
		hint.TextSize = 13
		hint.TextWrapped = true
		hint.TextXAlignment = Enum.TextXAlignment.Left
		hint.Text = "Laufe zu den leuchtenden Zonen:\nArena · Bey-Schmiede · Training"
		hint.Parent = panel
	end
	hint.Visible = true
end

local function applyClassicLayout()
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.35, 0.45)

	local startButton = panel:FindFirstChild("StartButton")
	if startButton then
		startButton.Visible = true
	end

	local hint = panel:FindFirstChild("HubHint")
	if hint then
		hint.Visible = false
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	if panel:FindFirstChild("LeaderboardLabel") and payload.leaderboard then
		local lines = {"🏆 Top Spieler:"}
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	end

	if payload.hubWorld then
		applyHubLayout()
	else
		applyClassicLayout()
	end

	gui.Enabled = true
end)

panel.StartButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
	Remotes.EnterArena:FireServer()
end)
