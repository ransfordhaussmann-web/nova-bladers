local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local HubConfig = require(ReplicatedStorage:WaitForChild("NovaBladers").HubConfig)
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

if not HubConfig.USE_3D_HUB then
	return
end

local function getOrCreateHud()
	local gui = player.PlayerGui:FindFirstChild("HubHUD")
	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "StatsBar"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(12, 12)
	frame.Size = UDim2.fromOffset(220, 110)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BackgroundTransparency = 0.15
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = frame

	local stats = Instance.new("TextLabel")
	stats.Name = "StatsLabel"
	stats.Size = UDim2.new(1, 0, 0, 60)
	stats.BackgroundTransparency = 1
	stats.Font = Enum.Font.Gotham
	stats.TextSize = 15
	stats.TextColor3 = Color3.fromRGB(230, 230, 240)
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.Text = ""
	stats.Parent = frame

	local mode = Instance.new("TextLabel")
	mode.Name = "ModeLabel"
	mode.Position = UDim2.fromOffset(0, 62)
	mode.Size = UDim2.new(1, 0, 0, 22)
	mode.BackgroundTransparency = 1
	mode.Font = Enum.Font.GothamBold
	mode.TextSize = 14
	mode.TextColor3 = Color3.fromRGB(120, 200, 255)
	mode.TextXAlignment = Enum.TextXAlignment.Left
	mode.Text = ""
	mode.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "HintLabel"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -24)
	hint.Size = UDim2.fromOffset(400, 28)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(180, 185, 200)
	hint.Text = "Lauf zu den Zonen: Arena · Bey Forge · Hall of Fame"
	hint.Parent = gui

	return gui
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

local function showHubHud(payload)
	hideBattleUi()
	local gui = getOrCreateHud()
	gui.Enabled = true

	local bar = gui.StatsBar
	bar.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins,
		payload.losses,
		payload.rank
	)
	bar.ModeLabel.Text = payload.modeLabel or "Modus: Training"
end

local function hideHubHud()
	local gui = player.PlayerGui:FindFirstChild("HubHUD")
	if gui then
		gui.Enabled = false
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		showHubHud(payload)
	else
		hideHubHud()
	end
end)

if Remotes:FindFirstChild("OpenBeySelect") then
	Remotes.OpenBeySelect.OnClientEvent:Connect(function()
		local select = player.PlayerGui:FindFirstChild("BeySelect")
		if select then
			select.Enabled = true
		end
	end)
end
