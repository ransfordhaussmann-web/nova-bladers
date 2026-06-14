local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
	local hubHud = player.PlayerGui:FindFirstChild("HubHud")
	if hubHud then hubHud.Enabled = false end
end

local legacyLobby = player.PlayerGui:FindFirstChild("Lobby")
if legacyLobby then
	local panel = legacyLobby:WaitForChild("Panel")

	Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
		if payload.hubMode then
			legacyLobby.Enabled = false
			return
		end

		hideOthers()
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
		legacyLobby.Enabled = true
	end)

	panel.StartButton.MouseButton1Click:Connect(function()
		legacyLobby.Enabled = false
		Remotes.EnterArena:FireServer()
	end)
end
