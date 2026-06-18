local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hallGui

local function hideBattleUi()
	local hud = playerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = playerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function getOrCreateHallGui()
	if hallGui then return hallGui end

	hallGui = Instance.new("ScreenGui")
	hallGui.Name = "HubHallOfFame"
	hallGui.ResetOnSpawn = false
	hallGui.Enabled = false
	hallGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(320, 280)
	frame.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
	frame.BorderSizePixel = 0
	frame.Parent = hallGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 32)
	title.Font = Enum.Font.GothamBold
	title.Text = "Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 210, 90)
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(12, 48)
	body.Size = UDim2.new(1, -24, 1, -92)
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.fromRGB(220, 225, 235)
	body.TextSize = 16
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = frame

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -12)
	close.Size = UDim2.fromOffset(120, 36)
	close.BackgroundColor3 = Color3.fromRGB(55, 60, 78)
	close.Font = Enum.Font.GothamBold
	close.Text = "Schließen"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.TextSize = 16
	close.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = close

	close.MouseButton1Click:Connect(function()
		hallGui.Enabled = false
	end)

	return hallGui
end

local function showHallOfFame(payload)
	local gui = getOrCreateHallGui()
	local lines = {
		string.format("Wins: %d", payload.wins or 0),
		string.format("Losses: %d", payload.losses or 0),
		string.format("Rank-Punkte: %d", payload.rank or 0),
		"",
		"Top Spieler:",
	}

	if payload.leaderboard and #payload.leaderboard > 0 then
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
	else
		table.insert(lines, "Noch keine Einträge")
	end

	gui.Panel.Body.Text = table.concat(lines, "\n")
	gui.Enabled = true
end

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.HallOfFameData.OnClientEvent:Connect(showHallOfFame)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
end)
