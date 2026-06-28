local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local inHub = false

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function applyLobbyPayload(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins or 0, payload.losses or 0, payload.rank or 0
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

local function setHubMode(enabled, showPanel)
	inHub = enabled
	panel.Visible = showPanel or not enabled
	if enabled then
		gui.Enabled = true
		hideOthers()
	else
		gui.Enabled = false
	end
end

Remotes.HubZoneChanged.OnClientEvent:Connect(function(payload)
	if inHub and payload.zoneId ~= "HallOfFame" then
		panel.Visible = false
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub == false then
		setHubMode(false)
		return
	end

	hideOthers()
	applyLobbyPayload(payload)
	setHubMode(payload.inHub == true, payload.showPanel == true)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	if inHub then return end
	gui.Enabled = false
	Remotes.EnterArena:FireServer()
end)
