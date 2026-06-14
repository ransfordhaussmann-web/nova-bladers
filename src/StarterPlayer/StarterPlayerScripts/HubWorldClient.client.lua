local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function findHub()
	return Workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
end

local function findZonePrompt(hub, zoneName)
	local zone = hub:WaitForChild(zoneName, 10)
	if not zone then
		return nil
	end
	local pad = zone:FindFirstChild("Pad")
	if not pad then
		return nil
	end
	return pad:FindFirstChild("ZonePrompt")
end

local function updateStatsBoard(hub, payload)
	local zone = hub:FindFirstChild("StatsBoard")
	if not zone then
		return
	end
	local display = zone:FindFirstChild("StatsBoardDisplay")
	if not display then
		return
	end
	local boardGui = display:FindFirstChild("BoardGui")
	if not boardGui then
		return
	end

	local statsText = boardGui:FindFirstChild("StatsText")
	if statsText then
		statsText.Text = string.format(
			"Deine Stats\nWins: %d\nLosses: %d\nRank: %d\n%s",
			payload.wins,
			payload.losses,
			payload.rank,
			payload.modeLabel or ""
		)
	end

	local leaderboardText = boardGui:FindFirstChild("LeaderboardText")
	if leaderboardText and payload.leaderboard then
		local lines = { "🏆 Top Spieler:" }
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		leaderboardText.Text = table.concat(lines, "\n")
	end
end

local function bindZonePrompts(hub)
	local arenaPrompt = findZonePrompt(hub, "ArenaGate")
	if arenaPrompt then
		arenaPrompt.Triggered:Connect(function()
			Remotes.EnterArena:FireServer()
		end)
	end

	local shopPrompt = findZonePrompt(hub, "BeyShop")
	if shopPrompt then
		shopPrompt.Triggered:Connect(function()
			local select = player.PlayerGui:FindFirstChild("BeySelect")
			if select then
				select.Enabled = true
			else
				Remotes.OpenBeySelect:FireServer()
			end
		end)
	end

	local statsPrompt = findZonePrompt(hub, "StatsBoard")
	if statsPrompt then
		statsPrompt.Triggered:Connect(function()
			local display = hub:FindFirstChild("StatsBoard")
			if display then
				local board = display:FindFirstChild("StatsBoardDisplay")
				if board then
					board.Transparency = 0
				end
			end
		end)
	end
end

local hub = findHub()
if hub then
	bindZonePrompts(hub)
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if hub then
		updateStatsBoard(hub, payload)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
