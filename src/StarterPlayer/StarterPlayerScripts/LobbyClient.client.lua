local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function formatStats(payload)
	return string.format(
		"Wins: %d  |  Losses: %d  |  Rank: %d",
		payload.wins, payload.losses, payload.rank
	)
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	panel.StatsLabel.Text = formatStats(payload)
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
		panel.LeaderboardLabel.Visible = false
	end

	-- Compact HUD: stats bar only, world is walkable
	if panel:FindFirstChild("StartButton") then
		panel.StartButton.Visible = false
	end
	if panel:FindFirstChild("TitleLabel") then
		panel.TitleLabel.Text = "Nova Bladers Hub"
	end

	gui.Enabled = true
end)

if panel:FindFirstChild("StartButton") then
	panel.StartButton.MouseButton1Click:Connect(function()
		Remotes.EnterArena:FireServer()
	end)
end
