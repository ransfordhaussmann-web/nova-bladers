local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local cachedPayload = nil
local hallGui = nil

local function formatLeaderboard(entries)
	local lines = {"🏆 Top Spieler:"}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function ensureHallGui()
	if hallGui then
		return hallGui
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubHallOfFame"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(320, 280)
	frame.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	frame.BorderSizePixel = 0
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 200, 60)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Ruhmeshalle"
	title.Parent = frame

	local stats = Instance.new("TextLabel")
	stats.Name = "StatsLabel"
	stats.Size = UDim2.new(1, -20, 0, 70)
	stats.Position = UDim2.fromOffset(10, 48)
	stats.BackgroundTransparency = 1
	stats.Font = Enum.Font.Gotham
	stats.TextSize = 18
	stats.TextColor3 = Color3.fromRGB(220, 220, 230)
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.Text = ""
	stats.Parent = frame

	local board = Instance.new("TextLabel")
	board.Name = "LeaderboardLabel"
	board.Size = UDim2.new(1, -20, 1, -130)
	board.Position = UDim2.fromOffset(10, 120)
	board.BackgroundTransparency = 1
	board.Font = Enum.Font.Gotham
	board.TextSize = 16
	board.TextColor3 = Color3.fromRGB(180, 190, 210)
	board.TextXAlignment = Enum.TextXAlignment.Left
	board.TextYAlignment = Enum.TextYAlignment.Top
	board.Text = ""
	board.Parent = frame

	hallGui = screen
	return screen
end

local function showHallOfFame()
	if not cachedPayload then
		return
	end
	local gui = ensureHallGui()
	local panel = gui.Panel
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		cachedPayload.wins or 0,
		cachedPayload.losses or 0,
		cachedPayload.rank or 0
	)
	panel.LeaderboardLabel.Text = formatLeaderboard(cachedPayload.leaderboard or {})
	gui.Enabled = true
end

local function hideHallOfFame()
	if hallGui then
		hallGui.Enabled = false
	end
end

local function openBeySelect()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	cachedPayload = payload
	if not payload.inHub then
		hideHallOfFame()
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(openBeySelect)

local function connectZone(zoneFolder)
	local trigger = zoneFolder:FindFirstChild("Trigger")
	local zoneId = zoneFolder:FindFirstChild("ZoneId")
	if not trigger or not zoneId then
		return
	end

	local prompt = trigger:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end

	prompt.Triggered:Connect(function()
		if zoneId.Value == "ArenaGate" then
			hideHallOfFame()
			Remotes.EnterArena:FireServer()
		elseif zoneId.Value == "BeyLab" then
			hideHallOfFame()
			Remotes.OpenBeySelect:FireServer()
		elseif zoneId.Value == "HallOfFame" then
			showHallOfFame()
		end
	end)

	prompt.PromptHidden:Connect(function()
		if zoneId.Value == "HallOfFame" then
			hideHallOfFame()
		end
	end)
end

local function watchHub()
	local hub = workspace:WaitForChild(HubConfig.FOLDER_NAME, 30)
	if not hub then
		return
	end
	local zones = hub:WaitForChild("Zones", 10)
	if not zones then
		return
	end
	for _, zoneFolder in zones:GetChildren() do
		connectZone(zoneFolder)
	end
	zones.ChildAdded:Connect(connectZone)
end

task.spawn(watchHub)
