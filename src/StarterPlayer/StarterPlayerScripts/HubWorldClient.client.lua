local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function findGui(name)
	return player:WaitForChild("PlayerGui"):FindFirstChild(name)
end

local function setGuiEnabled(name, enabled)
	local gui = findGui(name)
	if gui then
		gui.Enabled = enabled
	end
end

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	setGuiEnabled("BattleHUD", false)
	setGuiEnabled("Lobby", false)
	setGuiEnabled("MobileControls", false)
	setGuiEnabled("BeySelect", true)
end)

remotes.ShowHallOfFame.OnClientEvent:Connect(function(payload)
	local gui = findGui("Lobby")
	if not gui then
		return
	end

	local panel = gui:FindFirstChild("Panel")
	if not panel then
		return
	end

	if panel:FindFirstChild("StatsLabel") then
		panel.StatsLabel.Text = string.format(
			"Wins: %d\nLosses: %d\nRank: %d",
			payload.wins, payload.losses, payload.rank
		)
	end
	if panel:FindFirstChild("ModeLabel") then
		panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	end
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

	gui.Enabled = true
end)

remotes.EnterArena.OnClientEvent:Connect(function()
	setGuiEnabled("Lobby", false)
	setGuiEnabled("BeySelect", false)
	setGuiEnabled("BattleHUD", true)
	setGuiEnabled("MobileControls", true)
end)

remotes.ReturnToHub.OnClientEvent:Connect(function()
	setGuiEnabled("BattleHUD", false)
	setGuiEnabled("BeySelect", false)
	setGuiEnabled("MobileControls", false)
	setGuiEnabled("Lobby", false)
end)
