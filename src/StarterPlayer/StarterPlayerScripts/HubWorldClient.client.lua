local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldConfig = require(NovaBladers.HubWorldConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local function getHubFolder()
	return workspace:FindFirstChild(HubWorldConfig.HUB_FOLDER_NAME)
end

local function findBoardLabel(boardName)
	local hub = getHubFolder()
	if not hub then
		return nil
	end
	local board = hub:FindFirstChild(boardName)
	if not board then
		return nil
	end
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		return nil
	end
	return gui:FindFirstChildOfClass("TextLabel")
end

local function formatLeaderboard(entries)
	local lines = { "TOP 5" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function formatStats(payload)
	return string.format(
		"STATS\nW: %d  L: %d\nRang: %d\n%s",
		payload.wins,
		payload.losses,
		payload.rank,
		payload.modeLabel or ""
	)
end

local function updateHubDisplays(payload)
	local leaderboardLabel = findBoardLabel("LeaderboardBoard")
	if leaderboardLabel and payload.leaderboard then
		leaderboardLabel.Text = formatLeaderboard(payload.leaderboard)
	end

	local statsLabel = findBoardLabel("StatsBoard")
	if statsLabel then
		statsLabel.Text = formatStats(payload)
	end
end

local function applyLobbyPayload(payload)
	updateHubDisplays(payload)
end

Remotes.LobbyReady.OnClientEvent:Connect(applyLobbyPayload)
Remotes.RefreshLobby.OnClientEvent:Connect(applyLobbyPayload)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
