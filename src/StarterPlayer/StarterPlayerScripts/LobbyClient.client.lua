local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local inHub = true

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function applyStats(payload)
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

local function showPanel()
	hideOthers()
	gui.Enabled = true
end

local function hidePanel()
	gui.Enabled = false
end

Remotes:WaitForChild("HubState").OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" then
		inHub = payload.inHub == true
		if inHub then
			hidePanel()
		end
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	applyStats(payload)
	if payload.inHub or payload.showPanel then
		showPanel()
	elseif not inHub then
		showPanel()
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	hidePanel()
	Remotes.EnterArena:FireServer()
end)

if panel:FindFirstChild("CloseButton") then
	panel.CloseButton.MouseButton1Click:Connect(function()
		if inHub then
			hidePanel()
		end
	end)
end

-- Start hidden in walkable hub; zones open the panel on demand.
hidePanel()
