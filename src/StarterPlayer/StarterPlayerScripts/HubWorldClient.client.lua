local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local boundZones: { [Instance]: boolean } = {}

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

local function setBeySelectVisible(visible: boolean)
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = visible
	end
end

local function setLobbyPanelVisible(visible: boolean)
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if not gui then
		return
	end
	gui.Enabled = visible
end

local function applyHubVisibility()
	hideBattleUi()
	setBeySelectVisible(false)
	if inHub then
		setLobbyPanelVisible(false)
	else
		setLobbyPanelVisible(false)
	end
end

local function bindZonePrompt(zonePart: BasePart)
	if boundZones[zonePart] then
		return
	end
	boundZones[zonePart] = true

	local prompt = zonePart:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		return
	end

	local zoneId = zonePart:GetAttribute("ZoneId")
	prompt.Triggered:Connect(function()
		if not inHub then
			return
		end

		if zoneId == "ArenaGate" then
			Remotes.EnterArena:FireServer()
		elseif zoneId == "BeyShop" then
			Remotes.OpenBeySelect:FireServer()
		elseif zoneId == "StatsBoard" then
			Remotes.RefreshHubStats:FireServer()
		end
	end)
end

local function bindHubZones()
	local hub = Workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if not hub then
		return
	end

	local zones = hub:WaitForChild("Zones", 10)
	if not zones then
		return
	end

	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			bindZonePrompt(zonePart)
		end
	end

	zones.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			bindZonePrompt(child)
		end
	end)
end

Remotes.HubState.OnClientEvent:Connect(function(state: string)
	inHub = state == "hub"
	applyHubVisibility()
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	if not inHub then
		return
	end
	setBeySelectVisible(true)
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if not gui then
		return
	end
	local panel = gui:FindFirstChild("Panel")
	if not panel then
		return
	end

	local statsLabel = panel:FindFirstChild("StatsLabel")
	if statsLabel and statsLabel:IsA("TextLabel") then
		statsLabel.Text = string.format("Wins: %d\nLosses: %d\nRank: %d", payload.wins, payload.losses, payload.rank)
	end

	local modeLabel = panel:FindFirstChild("ModeLabel")
	if modeLabel and modeLabel:IsA("TextLabel") then
		modeLabel.Text = payload.modeLabel or "Modus: Training"
	end

	local leaderboardLabel = panel:FindFirstChild("LeaderboardLabel")
	if leaderboardLabel and leaderboardLabel:IsA("TextLabel") and payload.leaderboard then
		local lines = { "🏆 Top Spieler:" }
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		leaderboardLabel.Text = table.concat(lines, "\n")
	end
end)

applyHubVisibility()
task.spawn(bindHubZones)
