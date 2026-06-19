local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)

local HubDisplay = {}

local function findBody(zoneName)
	local hub = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if not hub then return nil end
	local zone = hub:FindFirstChild("Zones") and hub.Zones:FindFirstChild(zoneName)
	if not zone then return nil end

	for _, desc in zone:GetDescendants() do
		if desc:IsA("SurfaceGui") then
			local frame = desc:FindFirstChild("Frame")
			local body = frame and frame:FindFirstChild("Body")
			if body then return body end
		end
	end
	return nil
end

function HubDisplay.updateStats(payload)
	local body = findBody("StatsTerminal")
	if not body then return end
	body.Text = string.format(
		"Deine Stats\n\nWins: %d\nLosses: %d\nRank: %d\n\n%s",
		payload.wins,
		payload.losses,
		payload.rank,
		payload.modeLabel or ""
	)
end

function HubDisplay.updateLeaderboard(entries)
	local body = findBody("Leaderboard")
	if not body then return end
	local lines = { "🏆 Top Spieler", "" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	body.Text = table.concat(lines, "\n")
end

return HubDisplay
