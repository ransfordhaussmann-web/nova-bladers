local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local cachedPayload = nil

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function applyPayload(payload)
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

local function showLobby()
	hideOthers()
	if panel:FindFirstChild("StartButton") then
		panel.StartButton.Visible = true
	end
	gui.Enabled = true
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	cachedPayload = payload
	applyPayload(payload)

	if player:GetAttribute("inHub") then
		gui.Enabled = false
		return
	end

	showLobby()
end)

player:GetAttributeChangedSignal("inHub"):Connect(function()
	if player:GetAttribute("inHub") then
		gui.Enabled = false
		if panel:FindFirstChild("StartButton") then
			panel.StartButton.Visible = true
		end
	elseif cachedPayload then
		showLobby()
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
	Remotes.EnterArena:FireServer()
end)
