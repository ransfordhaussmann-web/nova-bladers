local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

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

local function hideLobby()
	gui.Enabled = false
end

local function hideBeySelect()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
end

local function applyLobbyPayload(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins,
		payload.losses,
		payload.rank
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
end

local function showHallPanel(payload)
	hideBattleUi()
	hideBeySelect()
	applyLobbyPayload(payload)
	gui.Enabled = true
	if panel:FindFirstChild("StartButton") then
		panel.StartButton.Visible = false
	end
end

hideLobby()
hideBattleUi()

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	applyLobbyPayload(payload)
end)

Remotes.ShowHallPanel.OnClientEvent:Connect(function(payload)
	showHallPanel(payload)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideLobby()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideLobby()
	hideBeySelect()
	hideBattleUi()
end)

if panel:FindFirstChild("StartButton") then
	panel.StartButton.MouseButton1Click:Connect(function()
		gui.Enabled = false
		Remotes.EnterArena:FireServer()
	end)
end
