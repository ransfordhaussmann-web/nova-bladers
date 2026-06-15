local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local function configureSidebar()
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -16, 0, 16)
	panel.Size = UDim2.new(0, 280, 0, 420)

	local background = gui:FindFirstChild("Background")
	if background and background:IsA("GuiObject") then
		background.BackgroundTransparency = 1
		background.Active = false
	end

	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
end

configureSidebar()

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function showLobby(payload)
	hideOthers()
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
	if panel:FindFirstChild("HintLabel") then
		panel.HintLabel.Text = "Zum Portal laufen oder Start drücken"
	end
	gui.Enabled = true
end

local function hideLobby()
	gui.Enabled = false
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub == false then
		hideLobby()
		return
	end
	showLobby(payload)
end)

panel.StartButton.MouseButton1Click:Connect(function()
	hideLobby()
	Remotes.EnterArena:FireServer()
end)

player:GetAttributeChangedSignal("InHub"):Connect(function()
	if player:GetAttribute("InHub") then
		if panel:FindFirstChild("HintLabel") then
			panel.HintLabel.Text = "Zum Portal laufen oder Start drücken"
		end
	else
		hideLobby()
	end
end)

player:GetAttributeChangedSignal("InArena"):Connect(function()
	if player:GetAttribute("InArena") then
		hideLobby()
	end
end)
