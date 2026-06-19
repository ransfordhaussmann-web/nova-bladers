local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local activeZone = nil
local lobbyPayload = nil

local promptGui = Instance.new("ScreenGui")
promptGui.Name = "HubPrompt"
promptGui.ResetOnSpawn = false
promptGui.Enabled = false
promptGui.Parent = player:WaitForChild("PlayerGui")

local promptLabel = Instance.new("TextLabel")
promptLabel.Name = "Prompt"
promptLabel.AnchorPoint = Vector2.new(0.5, 1)
promptLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
promptLabel.Size = UDim2.fromOffset(360, 40)
promptLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
promptLabel.BackgroundTransparency = 0.25
promptLabel.BorderSizePixel = 0
promptLabel.Font = Enum.Font.GothamBold
promptLabel.TextColor3 = Color3.new(1, 1, 1)
promptLabel.TextSize = 18
promptLabel.Text = ""
promptLabel.Parent = promptGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = promptLabel

local function getCharacterPosition()
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function findNearestZone(position)
	local nearest = nil
	local nearestDist = HubConfig.INTERACT_RANGE

	for _, zone in HubConfig.ZONES do
		local zonePos = HubConfig.HUB_ORIGIN + zone.position
		local dist = (Vector3.new(position.X, zonePos.Y, position.Z) - zonePos).Magnitude
		if dist <= nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end

	return nearest
end

local function updatePrompt()
	if not inHub then
		promptGui.Enabled = false
		activeZone = nil
		return
	end

	local position = getCharacterPosition()
	if not position then
		promptGui.Enabled = false
		activeZone = nil
		return
	end

	local zone = findNearestZone(position)
	activeZone = zone
	if zone then
		promptGui.Enabled = true
		promptLabel.Text = string.format("[%s] %s", zone.name, zone.hint)
	else
		promptGui.Enabled = false
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

local function hideLobbyGui()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	lobbyPayload = payload
	inHub = payload.inHub ~= false
	hideBattleUi()
	if inHub then
		hideLobbyGui()
	else
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then
			lobby.Enabled = true
		end
	end
end)

Remotes.ShowHallPanel.OnClientEvent:Connect(function(payload)
	lobbyPayload = payload
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if not lobby then
		return
	end

	local panel = lobby:FindFirstChild("Panel")
	if panel then
		panel.StatsLabel.Text = string.format(
			"Wins: %d\nLosses: %d\nRank: %d",
			payload.wins, payload.losses, payload.rank
		)
		panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
		local leaderboardLabel = panel:FindFirstChild("LeaderboardLabel")
		if leaderboardLabel and payload.leaderboard then
			local lines = {"🏆 Top Spieler:"}
			for _, entry in payload.leaderboard do
				table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
			end
			if #payload.leaderboard == 0 then
				table.insert(lines, "Noch keine Einträge")
			end
			leaderboardLabel.Text = table.concat(lines, "\n")
		end
	end

	hideBattleUi()
	lobby.Enabled = true
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	inHub = false
	promptGui.Enabled = false
	hideLobbyGui()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub or not activeZone then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		Remotes.HubZoneAction:FireServer(activeZone.action)
	end
end)

RunService.Heartbeat:Connect(updatePrompt)

hideLobbyGui()
