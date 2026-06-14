local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hud = Instance.new("ScreenGui")
hud.Name = "HubHUD"
hud.ResetOnSpawn = false
hud.Enabled = false
hud.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "StatsFrame"
frame.AnchorPoint = Vector2.new(0, 0)
frame.Position = UDim2.fromOffset(12, 12)
frame.Size = UDim2.fromOffset(220, 120)
frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
frame.BackgroundTransparency = 0.25
frame.BorderSizePixel = 0
frame.Parent = hud

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 22)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.Text = "Nova Hub"
title.Parent = frame

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "StatsLabel"
statsLabel.Size = UDim2.new(1, 0, 0, 52)
statsLabel.Position = UDim2.fromOffset(0, 26)
statsLabel.BackgroundTransparency = 1
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 14
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
statsLabel.Text = "Wins: 0\nLosses: 0"
statsLabel.Parent = frame

local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "ModeLabel"
modeLabel.Size = UDim2.new(1, 0, 0, 18)
modeLabel.Position = UDim2.fromOffset(0, 82)
modeLabel.BackgroundTransparency = 1
modeLabel.Font = Enum.Font.GothamMedium
modeLabel.TextSize = 13
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
modeLabel.Text = "Modus: Training"
modeLabel.Parent = frame

local toast = Instance.new("TextLabel")
toast.Name = "StatsToast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -24)
toast.Size = UDim2.fromOffset(360, 160)
toast.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
toast.BackgroundTransparency = 0.1
toast.BorderSizePixel = 0
toast.Visible = false
toast.Font = Enum.Font.Gotham
toast.TextSize = 15
toast.TextColor3 = Color3.fromRGB(235, 235, 245)
toast.TextWrapped = true
toast.Parent = hud

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = toast

local function hideBattleUi()
	local battleHud = playerGui:FindFirstChild("BattleHUD")
	if battleHud then
		battleHud.Enabled = false
	end
	local mobile = playerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

local function formatLeaderboard(lines, entries)
	table.insert(lines, "🏆 Top Spieler:")
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function applyPayload(payload)
	statsLabel.Text = string.format("Wins: %d\nLosses: %d\nRank: %d", payload.wins, payload.losses, payload.rank)
	modeLabel.Text = payload.modeLabel or "Modus: Training"
end

local function setHubMode(inHub)
	hud.Enabled = inHub
	hideBattleUi()
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	local beySelect = playerGui:FindFirstChild("BeySelect")
	if beySelect then
		beySelect.Enabled = false
	end
end

local function showStatsToast(payload)
	local lines = {
		"══ Ruhmeshalle ══",
		string.format("Wins: %d  |  Losses: %d  |  Rank: %d", payload.wins, payload.losses, payload.rank),
		"",
	}
	toast.Text = formatLeaderboard(lines, payload.leaderboard or {})
	toast.Visible = true
	task.delay(5, function()
		toast.Visible = false
	end)
end

Remotes.HubState.OnClientEvent:Connect(function(payload)
	if payload.inHub == false then
		hud.Enabled = false
		return
	end
	setHubMode(true)
	applyPayload(payload)
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub == false then
		return
	end
	setHubMode(true)
	applyPayload(payload)
end)

Remotes.RefreshHubStats.OnClientEvent:Connect(function(payload)
	if payload.inHub == false then
		return
	end
	applyPayload(payload)
	showStatsToast(payload)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local beySelect = playerGui:FindFirstChild("BeySelect")
	if beySelect then
		beySelect.Enabled = true
	end
end)
