local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function formatStats(payload)
	return string.format(
		"Wins: %d\nLosses: %d\nRank: %d\n\n%s",
		payload.wins,
		payload.losses,
		payload.rank,
		payload.modeLabel or "Modus: Training"
	)
end

local function updateBoard(boardKey, text)
	local board = HubWorldBuilder.getBoard(boardKey)
	if not board then return end
	local gui = board:FindFirstChild("BoardGui")
	if not gui then return end
	local body = gui:FindFirstChild("Body")
	if body then
		body.Text = text
	end
end

local function updateHubBoards(payload)
	updateBoard("Leaderboard", formatLeaderboard(payload.leaderboard or {}))
	updateBoard("Stats", formatStats(payload))
end

local function hubCountFromMode(modeLabel)
	if string.find(modeLabel or "", "FFA") then
		return 3
	elseif string.find(modeLabel or "", "1v1") then
		return 2
	end
	return 1
end

local function updatePortalPrompts(modeLabel)
	local hubCount = hubCountFromMode(modeLabel)
	local portals = HubWorldBuilder.getZonePortals()
	for zoneId, portal in portals do
		local pad = portal:FindFirstChild("Pad")
		if not pad then
			continue
		end
		local prompt = pad:FindFirstChild("EnterPrompt")
		if not prompt or zoneId == "BeySelect" then
			continue
		end

		local enabled = true
		if zoneId == "OneVOne" then
			enabled = hubCount >= 2
		elseif zoneId == "FFA" then
			enabled = hubCount >= 3
		end
		prompt.Enabled = enabled
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	updateHubBoards(payload)
	updatePortalPrompts(payload.modeLabel)
end)

-- Boards aktualisieren, sobald der Hub im Workspace erscheint
task.spawn(function()
	local hub = workspace:WaitForChild(HubConfig.ROOT_NAME, 30)
	if hub then
		updateBoard("Leaderboard", "Warte auf Daten…")
		updateBoard("Stats", "Warte auf Daten…")
	end
end)
