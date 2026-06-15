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

local function applyCompactHud(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d  Losses: %d  Rang: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	if panel:FindFirstChild("LeaderboardLabel") and payload.leaderboard then
		local lines = { "🏆 Top 5" }
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "—")
		end
		panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyCompactHud(payload)

	-- 3D hub: walkable world with in-world boards; keep a small corner HUD.
	gui.Enabled = true
	if panel:FindFirstChild("StartButton") then
		panel.StartButton.Visible = false
	end
	if panel:FindFirstChild("HintLabel") then
		panel.HintLabel.Text = "Lauf zur Arena oder nutze E am Tor"
	else
		local hint = Instance.new("TextLabel")
		hint.Name = "HintLabel"
		hint.Size = UDim2.new(1, -16, 0, 28)
		hint.Position = UDim2.new(0, 8, 1, -36)
		hint.BackgroundTransparency = 1
		hint.Font = Enum.Font.Gotham
		hint.TextSize = 14
		hint.TextColor3 = Color3.fromRGB(200, 210, 230)
		hint.TextXAlignment = Enum.TextXAlignment.Left
		hint.Text = "Lauf zur Arena oder nutze E am Tor"
		hint.Parent = panel
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.inHub == false then
		gui.Enabled = false
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
	Remotes.EnterArena:FireServer()
end)
