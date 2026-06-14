local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function findStatsLabel()
	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then
		return nil
	end
	local statsZone = hub:FindFirstChild("StatsBoard")
	if not statsZone then
		return nil
	end
	local board = statsZone:FindFirstChild("Board")
	local gui = board and board:FindFirstChild("StatsSurface")
	return gui and gui:FindFirstChild("StatsLabel")
end

local function formatLeaderboard(entries)
	if not entries or #entries == 0 then
		return "Noch keine Einträge"
	end
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	return table.concat(lines, "\n")
end

local function updateStatsBoard(payload)
	local label = findStatsLabel()
	if not label then
		return
	end
	label.Text = string.format(
		"Nova Bladers\n\n%s\n\nWins: %d  Losses: %d\nRank: %d\n\n🏆 Top Spieler:\n%s",
		payload.modeLabel or "Modus: Training",
		payload.wins or 0,
		payload.losses or 0,
		payload.rank or 0,
		formatLeaderboard(payload.leaderboard)
	)
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.hubMode then
		updateStatsBoard(payload)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = true
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = true
	end
end)
