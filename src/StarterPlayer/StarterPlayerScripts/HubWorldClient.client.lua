local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
if not HubConfig.USE_3D_HUB then
	return
end

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function hideBattleUi()
	for _, name in { "BattleHUD", "BeySelect", "MobileControls" } do
		local gui = player.PlayerGui:FindFirstChild(name)
		if gui then gui.Enabled = false end
	end
end

local function hideLegacyLobby()
	local legacy = player.PlayerGui:FindFirstChild("Lobby")
	if legacy then legacy.Enabled = false end
end

local gui = Instance.new("ScreenGui")
gui.Name = "HubHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.new(0, 16, 0, 16)
panel.Size = UDim2.new(0, 220, 0, 150)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 8)
title.Size = UDim2.new(1, -24, 0, 22)
title.Font = Enum.Font.GothamBold
title.Text = "Nova Hub"
title.TextColor3 = Color3.fromRGB(180, 150, 255)
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "StatsLabel"
statsLabel.BackgroundTransparency = 1
statsLabel.Position = UDim2.new(0, 12, 0, 34)
statsLabel.Size = UDim2.new(1, -24, 0, 48)
statsLabel.Font = Enum.Font.Gotham
statsLabel.Text = "Wins: 0\nLosses: 0\nRank: 0"
statsLabel.TextColor3 = Color3.new(1, 1, 1)
statsLabel.TextSize = 14
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Parent = panel

local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "ModeLabel"
modeLabel.BackgroundTransparency = 1
modeLabel.Position = UDim2.new(0, 12, 0, 86)
modeLabel.Size = UDim2.new(1, -24, 0, 18)
modeLabel.Font = Enum.Font.GothamMedium
modeLabel.Text = "Modus: Training"
modeLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
modeLabel.TextSize = 13
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Parent = panel

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -24)
hintLabel.Size = UDim2.new(0, 420, 0, 40)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.2
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.Gotham
hintLabel.Text = "Erkunde den Hub — Arena-Tor, Bey-Labor, Ruhmeshalle"
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 15
hintLabel.TextWrapped = true
hintLabel.Parent = gui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 8)
hintCorner.Parent = hintLabel

local function updateStats(payload)
	statsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	modeLabel.Text = payload.modeLabel or "Modus: Training"
end

hideLegacyLobby()
hideBattleUi()
gui.Enabled = true

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideLegacyLobby()
	hideBattleUi()
	updateStats(payload)
	gui.Enabled = true
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload and payload.hint then
		hintLabel.Text = string.format("[%s] %s", payload.label or "Zone", payload.hint)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	hideLegacyLobby()
	gui.Enabled = true
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	gui.Enabled = false
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = true end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = true end
end)
