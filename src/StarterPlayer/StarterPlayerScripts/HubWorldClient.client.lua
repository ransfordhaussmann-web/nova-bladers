local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function findHub()
	return workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
end

local function setBoardText(boardName, bodyText)
	local hub = findHub()
	if not hub then
		return
	end
	local board = hub:FindFirstChild(boardName)
	if not board then
		return
	end
	local gui = board:FindFirstChild("BoardGui")
	local body = gui and gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Body")
	if body then
		body.Text = bodyText
	end
end

local function formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		return "Noch keine Einträge"
	end
	return table.concat(lines, "\n")
end

local function formatStats(payload)
	return string.format(
		"Wins: %d\nLosses: %d\nRank: %d\n\n%s",
		payload.wins,
		payload.losses,
		payload.rank,
		payload.modeLabel or ""
	)
end

local function updateBoards(payload)
	setBoardText("LeaderboardBoard", formatLeaderboard(payload.leaderboard or {}))
	setBoardText("StatsBoard", formatStats(payload))
end

local function bindPrompts()
	local hub = findHub()
	if not hub then
		return
	end

	for zoneName, zone in HubConfig.ZONES do
		if zone.promptAction then
			local part = hub:FindFirstChild(zoneName)
			local prompt = part and part:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function(triggerPlayer)
					if triggerPlayer ~= player then
						return
					end
					if zone.promptAction == "EnterArena" then
						Remotes.EnterArena:FireServer()
					elseif zone.promptAction == "OpenBeySelect" then
						local select = player.PlayerGui:FindFirstChild("BeySelect")
						if select then
							select.Enabled = true
						end
					end
				end)
			end
		end
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(updateBoards)

task.defer(function()
	local hub = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if hub then
		bindPrompts()
	end
end)

return {
	updateBoards = updateBoards,
	isHubActive = function()
		return findHub() ~= nil
	end,
}
