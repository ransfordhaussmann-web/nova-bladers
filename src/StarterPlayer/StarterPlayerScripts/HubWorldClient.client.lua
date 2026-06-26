local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local hubFolder = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)

local function findBoardBody(boardName)
	if not hubFolder then return nil end
	local board = hubFolder:FindFirstChild(boardName, true)
	if not board then return nil end
	local gui = board:FindFirstChildWhichIsA("SurfaceGui")
	if not gui then return nil end
	local root = gui:FindFirstChild("Root")
	return root and root:FindFirstChild("Body")
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

local function updateHubBoards(payload)
	local statsBody = findBoardBody("StatsBoard")
	if statsBody then
		statsBody.Text = string.format(
			"Wins: %d\nLosses: %d\nRang: %d\n\n%s",
			payload.wins,
			payload.losses,
			payload.rank,
			payload.modeLabel or ""
		)
	end

	local lbBody = findBoardBody("LeaderboardBoard")
	if lbBody and payload.leaderboard then
		lbBody.Text = formatLeaderboard(payload.leaderboard)
	end
end

local function setHubLobbyGui(enabled)
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = enabled
	end
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideBattleUi()
	if hubFolder then
		setHubLobbyGui(false)
		updateHubBoards(payload)
	else
		setHubLobbyGui(true)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

-- 3D-Hub aktiv: Screen-Lobby ausblenden
if hubFolder then
	setHubLobbyGui(false)
end
