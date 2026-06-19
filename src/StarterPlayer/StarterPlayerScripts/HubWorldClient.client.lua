local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local latestPayload
local activeZone
local hintGui

local function getZonesFolder()
	local hub = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	return hub and hub:FindFirstChild("Zones")
end

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubHint"
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -24)
	label.Size = UDim2.fromOffset(400, 40)
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 16
	label.Visible = false
	label.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	hintGui = screen
	return screen
end

local function findZoneConfig(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

local function getNearestZone()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local zonesFolder = getZonesFolder()
	if not root or not zonesFolder then return nil end

	local nearest
	local nearestDist = math.huge

	for _, marker in zonesFolder:GetChildren() do
		if marker:IsA("BasePart") then
			local dist = (marker.Position - root.Position).Magnitude
			local reach = math.max(marker.Size.X, marker.Size.Z) / 2 + 4
			if dist <= reach and dist < nearestDist then
				nearest = marker
				nearestDist = dist
			end
		end
	end

	return nearest
end

local function updateHallOfFamePanel(show)
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if not lobby or not latestPayload or not latestPayload.inHub then return end

	local panel = lobby:FindFirstChild("Panel")
	if not panel then return end

	if show and latestPayload then
		panel.StatsLabel.Text = string.format(
			"Wins: %d\nLosses: %d\nRank: %d",
			latestPayload.wins, latestPayload.losses, latestPayload.rank
		)
		panel.ModeLabel.Text = latestPayload.modeLabel or "Modus: Training"
		if panel:FindFirstChild("LeaderboardLabel") and latestPayload.leaderboard then
			local lines = {"🏆 Top Spieler:"}
			for _, entry in latestPayload.leaderboard do
				table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
			end
			if #latestPayload.leaderboard == 0 then
				table.insert(lines, "Noch keine Einträge")
			end
			panel.LeaderboardLabel.Text = table.concat(lines, "\n")
		end
		if panel:FindFirstChild("StartButton") then
			panel.StartButton.Visible = false
		end
		lobby.Enabled = true
	else
		lobby.Enabled = false
	end
end

local function setActiveZone(marker)
	local zoneId = marker and marker:GetAttribute("ZoneId")
	if activeZone == zoneId then return end
	activeZone = zoneId

	local hint = ensureHintGui().HintLabel
	if zoneId then
		local config = findZoneConfig(zoneId)
		hint.Text = config and config.hint or "Drücke E"
		hint.Visible = true
	else
		hint.Visible = false
	end

	updateHallOfFamePanel(zoneId == "HallOfFame")
end

local function performZoneAction()
	if not activeZone or not latestPayload or not latestPayload.inHub then return end

	local config = findZoneConfig(activeZone)
	if not config then return end

	if config.action == "enterArena" then
		Remotes.EnterArena:FireServer()
	elseif config.action == "openBeySelect" then
		Remotes.OpenBeySelect:FireServer()
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	latestPayload = payload
	if not payload.inHub then
		activeZone = nil
		local hint = hintGui and hintGui:FindFirstChild("HintLabel")
		if hint then hint.Visible = false end
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		performZoneAction()
	end
end)

RunService.Heartbeat:Connect(function()
	if not latestPayload or not latestPayload.inHub then
		if activeZone then setActiveZone(nil) end
		return
	end
	setActiveZone(getNearestZone())
end)
