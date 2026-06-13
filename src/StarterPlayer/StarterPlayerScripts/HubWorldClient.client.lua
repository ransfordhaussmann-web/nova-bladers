local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local statsPayload

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

local function hideLobbyScreen()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

local function openBeySelect()
	hideLobbyScreen()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function formatLeaderboard(entries)
	local lines = { "Top Spieler:" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function updateStatsBoard()
	if not statsPayload then
		return
	end

	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then
		return
	end

	local board = hub:FindFirstChild("StatsBoard")
	if not board then
		return
	end

	local surface = board:FindFirstChild("StatsDisplay")
	if not surface then
		return
	end

	local panel = surface:FindFirstChild("Panel")
	if not panel then
		return
	end

	local statsLabel = panel:FindFirstChild("StatsLabel")
	if statsLabel then
		statsLabel.Text = string.format(
			"Wins: %d\nLosses: %d\nRank: %d\n%s",
			statsPayload.wins,
			statsPayload.losses,
			statsPayload.rank,
			statsPayload.modeLabel or ""
		)
	end

	local boardLabel = panel:FindFirstChild("LeaderboardLabel")
	if boardLabel and statsPayload.leaderboard then
		boardLabel.Text = formatLeaderboard(statsPayload.leaderboard)
	end
end

local function onLobbyReady(payload)
	statsPayload = payload
	hideLobbyScreen()
	hideBattleUi()
	updateStatsBoard()
end

local function onHubState(state)
	if state.inHub then
		hideLobbyScreen()
		hideBattleUi()
		updateStatsBoard()
	end
end

local function onZoneTriggered(zoneId)
	if zoneId == "ArenaGate" then
		hideLobbyScreen()
		local select = player.PlayerGui:FindFirstChild("BeySelect")
		if select then
			select.Enabled = false
		end
		Remotes.EnterArena:FireServer()
	elseif zoneId == "BeyShop" then
		openBeySelect()
	elseif zoneId == "StatsBoard" then
		Remotes.RefreshHubStats:FireServer()
		updateStatsBoard()
	end
end

local function bindZone(part)
	local zoneId = part:GetAttribute("HubZone")
	if not zoneId then
		return
	end

	local prompt = part:FindFirstChild("HubPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end

	prompt.Triggered:Connect(function()
		onZoneTriggered(zoneId)
	end)
end

local function bindHubZones()
	local hub = Workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if not hub then
		return
	end

	for _, child in hub:GetChildren() do
		if child:IsA("BasePart") then
			bindZone(child)
		end
	end

	hub.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			bindZone(child)
		end
	end)
end

Remotes.LobbyReady.OnClientEvent:Connect(onLobbyReady)
Remotes.HubState.OnClientEvent:Connect(onHubState)
Remotes.OpenBeySelect.OnClientEvent:Connect(openBeySelect)

hideLobbyScreen()
bindHubZones()
