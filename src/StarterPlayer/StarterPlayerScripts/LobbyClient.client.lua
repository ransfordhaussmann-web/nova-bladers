local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local inHubWorld = false
local statsVisible = false

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function applyPanelVisibility()
	if inHubWorld then
		gui.Enabled = statsVisible
		panel.Visible = statsVisible
	else
		gui.Enabled = true
		panel.Visible = true
	end
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

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	updatePanel(payload)

	inHubWorld = payload.inHub == true

	if payload.inArena then
		gui.Enabled = false
		return
	end

	if inHubWorld then
		if payload.showStatsPanel then
			statsVisible = true
		else
			statsVisible = false
		end
		applyPanelVisibility()
		return
	end

	statsVisible = true
	applyPanelVisibility()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHubWorld then return end
	if input.KeyCode == Enum.KeyCode.R then
		statsVisible = not statsVisible
		applyPanelVisibility()
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
	Remotes.EnterArena:FireServer()
end)
