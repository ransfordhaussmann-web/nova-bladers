local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubZoneAction = Remotes:WaitForChild("HubZoneAction")

local function findGui(name)
	return player:WaitForChild("PlayerGui"):FindFirstChild(name)
end

local function applyPayloadToPanel(panel, payload)
	if not panel then
		return
	end
	if panel:FindFirstChild("StatsLabel") then
		panel.StatsLabel.Text = string.format(
			"Wins: %d\nLosses: %d\nRank: %d",
			payload.wins,
			payload.losses,
			payload.rank
		)
	end
	if panel:FindFirstChild("ModeLabel") then
		panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	end
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

local function showLobbyPanel(payload, focus)
	local gui = findGui("Lobby")
	if not gui then
		return
	end
	local panel = gui:FindFirstChild("Panel")
	applyPayloadToPanel(panel, payload)
	if focus == "stats" and panel and panel:FindFirstChild("StatsLabel") then
		panel.Visible = true
	elseif focus == "leaderboard" and panel and panel:FindFirstChild("LeaderboardLabel") then
		panel.Visible = true
	else
		panel.Visible = true
	end
	gui.Enabled = true
end

local function openBeySelect()
	local select = findGui("BeySelect")
	if select then
		select.Enabled = true
	end
end

HubZoneAction.OnClientEvent:Connect(function(action, payload)
	if action == "openBeySelect" then
		openBeySelect()
	elseif action == "showStats" then
		showLobbyPanel(payload, "stats")
	elseif action == "showLeaderboard" then
		showLobbyPanel(payload, "leaderboard")
	end
end)
