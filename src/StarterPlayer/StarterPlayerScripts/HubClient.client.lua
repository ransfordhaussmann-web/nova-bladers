local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local function findBillboard(name)
	local hub = workspace:WaitForChild("NovaBladersHub", 30)
	if not hub then
		return nil
	end
	local anchor = hub:FindFirstChild(name, true)
	if not anchor then
		return nil
	end
	local billboard = anchor:FindFirstChild("HubBillboard")
	if not billboard then
		return nil
	end
	return billboard:FindFirstChild("Frame") and billboard.Frame:FindFirstChild("BodyLabel")
end

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

local function updateWorldBillboards(payload)
	local statsLabel = findBillboard("HubStatsBoard")
	if statsLabel then
		statsLabel.Text = string.format(
			"Wins: %d\nLosses: %d\nRank: %d\n\n%s",
			payload.wins,
			payload.losses,
			payload.rank,
			payload.modeLabel or "Modus: Training"
		)
	end

	local leaderboardLabel = findBillboard("HubLeaderboard")
	if leaderboardLabel and payload.leaderboard then
		leaderboardLabel.Text = formatLeaderboard(payload.leaderboard)
	end
end

local function bindArenaPrompt()
	local hub = workspace:WaitForChild("NovaBladersHub", 30)
	if not hub then
		return
	end
	local gate = hub:FindFirstChild("ArenaGate", true)
	if not gate then
		return
	end
	local prompt = gate:FindFirstChild("EnterArenaPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function()
		Remotes.EnterArena:FireServer()
	end)
end

Remotes.LobbyReady.OnClientEvent:Connect(updateWorldBillboards)
Remotes.HubStateChanged.OnClientEvent:Connect(function(state)
	player:SetAttribute("ClientInHub", state.inHub == true)
end)

bindArenaPrompt()
