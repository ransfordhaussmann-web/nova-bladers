local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local hubGui

local function ensureHubGui()
	if hubGui then
		return hubGui
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubOverlay"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.Parent = playerGui

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0, 12)
	hint.Size = UDim2.fromOffset(520, 36)
	hint.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	hint.BackgroundTransparency = 0.35
	hint.BorderSizePixel = 0
	hint.Font = Enum.Font.GothamMedium
	hint.TextColor3 = Color3.fromRGB(220, 230, 245)
	hint.TextSize = 16
	hint.Text = "Laufe zu Arena-Tor, Bey-Shop oder Ruhmeshalle — E zum Interagieren"
	hint.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = hint

	local stats = Instance.new("TextLabel")
	stats.Name = "Stats"
	stats.AnchorPoint = Vector2.new(1, 0)
	stats.Position = UDim2.new(1, -12, 0, 12)
	stats.Size = UDim2.fromOffset(200, 80)
	stats.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	stats.BackgroundTransparency = 0.35
	stats.BorderSizePixel = 0
	stats.Font = Enum.Font.Gotham
	stats.TextColor3 = Color3.fromRGB(200, 210, 230)
	stats.TextSize = 14
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.Text = ""
	stats.Parent = screen

	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0, 8)
	statsCorner.Parent = stats

	local mode = Instance.new("TextLabel")
	mode.Name = "Mode"
	mode.AnchorPoint = Vector2.new(0, 1)
	mode.Position = UDim2.new(0, 12, 1, -12)
	mode.Size = UDim2.fromOffset(220, 28)
	mode.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	mode.BackgroundTransparency = 0.35
	mode.BorderSizePixel = 0
	mode.Font = Enum.Font.GothamBold
	mode.TextColor3 = Color3.fromRGB(140, 200, 255)
	mode.TextSize = 15
	mode.Text = "Modus: Training"
	mode.Parent = screen

	local modeCorner = Instance.new("UICorner")
	modeCorner.CornerRadius = UDim.new(0, 8)
	modeCorner.Parent = mode

	hubGui = screen
	return screen
end

local function updateStats(payload)
	local gui = ensureHubGui()
	if payload.stats then
		gui.Stats.Text = string.format(
			"Wins: %d\nLosses: %d\nRank: #%d",
			payload.stats.wins,
			payload.stats.losses,
			payload.stats.rank
		)
	elseif payload.wins then
		gui.Stats.Text = string.format(
			"Wins: %d\nLosses: %d\nRank: #%d",
			payload.wins,
			payload.losses,
			payload.rank
		)
	end
	if payload.modeLabel then
		gui.Mode.Text = payload.modeLabel
	end
end

local function setHubVisible(visible)
	local gui = ensureHubGui()
	gui.Enabled = visible
end

Remotes.HubState.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	setHubVisible(inHub)
	if inHub then
		updateStats(payload)
	end
end)

Remotes.RefreshHubStats.OnClientEvent:Connect(function(payload)
	if inHub then
		updateStats(payload)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
