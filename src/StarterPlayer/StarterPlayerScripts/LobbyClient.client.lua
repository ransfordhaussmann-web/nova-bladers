local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local inHub = true
local statsVisible = false

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
		local lines = {"🏆 Top Spieler:"}
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	end
end

local function refreshLobbyVisibility()
	hideOthers()
	if inHub and not statsVisible then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
end

Remotes.HubStateChanged.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	if inHub then
		statsVisible = false
	end
	refreshLobbyVisibility()
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	updatePanel(payload)
	if inHub then
		statsVisible = true
	end
	refreshLobbyVisibility()
end)

panel.StartButton.MouseButton1Click:Connect(function()
	statsVisible = false
	gui.Enabled = false
	Remotes.EnterArena:FireServer()
end)

refreshLobbyVisibility()
