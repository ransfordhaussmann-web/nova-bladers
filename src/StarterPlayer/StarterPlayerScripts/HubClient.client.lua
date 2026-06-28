local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function getOrCreateHubHud()
	local gui = player.PlayerGui:FindFirstChild("HubHUD")
	if gui then return gui end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubHUD"
	gui.ResetOnSpawn = false
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(12, 12)
	frame.Size = UDim2.fromOffset(220, 120)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(10, 6)
	title.Size = UDim2.new(1, -20, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.Text = "Nova Hub"
	title.TextColor3 = Color3.fromRGB(120, 180, 255)
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local stats = Instance.new("TextLabel")
	stats.Name = "StatsLabel"
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.fromOffset(10, 30)
	stats.Size = UDim2.new(1, -20, 0, 52)
	stats.Font = Enum.Font.Gotham
	stats.Text = ""
	stats.TextColor3 = Color3.fromRGB(220, 225, 240)
	stats.TextSize = 14
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.TextWrapped = true
	stats.Parent = frame

	local mode = Instance.new("TextLabel")
	mode.Name = "ModeLabel"
	mode.BackgroundTransparency = 1
	mode.Position = UDim2.fromOffset(10, 84)
	mode.Size = UDim2.new(1, -20, 0, 18)
	mode.Font = Enum.Font.GothamMedium
	mode.Text = ""
	mode.TextColor3 = Color3.fromRGB(160, 170, 200)
	mode.TextSize = 13
	mode.TextXAlignment = Enum.TextXAlignment.Left
	mode.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "HintLabel"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -24)
	hint.Size = UDim2.fromOffset(400, 40)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamMedium
	hint.Text = "Gehe zum Portal oder drücke E am Arena-Tor"
	hint.TextColor3 = Color3.fromRGB(200, 210, 230)
	hint.TextSize = 15
	hint.Parent = gui

	return gui
end

Remotes.HubState.OnClientEvent:Connect(function(payload)
	if payload.state == "hub" then
		hideBattleUi()
		local hubHud = getOrCreateHubHud()
		hubHud.Enabled = true
		if payload.modeLabel then
			hubHud.Panel.ModeLabel.Text = payload.modeLabel
		end
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideBattleUi()

	local legacyGui = player.PlayerGui:FindFirstChild("Lobby")
	if legacyGui and legacyGui:FindFirstChild("Panel") then
		legacyGui.Enabled = false
	end

	local hubHud = getOrCreateHubHud()
	hubHud.Panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	hubHud.Panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	hubHud.Enabled = true
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	local hubHud = player.PlayerGui:FindFirstChild("HubHUD")
	if hubHud then hubHud.Enabled = false end
end)
