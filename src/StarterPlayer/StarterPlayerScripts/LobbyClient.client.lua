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

local function updatePanel(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	if panel:FindFirstChild("LeaderboardLabel") and payload.leaderboard then
		local lines = {"Top Spieler:"}
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Eintraege")
		end
		panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	updatePanel(payload)
	if player:GetAttribute("NovaBladers_ShowStatsPanel") then
		gui.Enabled = true
	else
		gui.Enabled = false
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
	player:SetAttribute("NovaBladers_ShowStatsPanel", false)
	Remotes.EnterArena:FireServer()
end)

player:GetAttributeChangedSignal("NovaBladers_OpenBeySelect"):Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select and player:GetAttribute("NovaBladers_OpenBeySelect") then
		select.Enabled = true
		player:SetAttribute("NovaBladers_OpenBeySelect", false)
	end
end)
