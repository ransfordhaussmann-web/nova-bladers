local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local use3DHub = NovaBladers:GetAttribute("Use3DHub") == true
local inHub = true

local function hideBattleUi()
	local hud = playerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = playerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = playerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function getOrCreateHud()
	local gui = playerGui:FindFirstChild("HubHUD")
	if gui then return gui end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(12, 12)
	frame.Size = UDim2.fromOffset(220, 160)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.Text = "Nova Hub"
	title.Parent = frame

	local modeLabel = Instance.new("TextLabel")
	modeLabel.Name = "ModeLabel"
	modeLabel.LayoutOrder = 2
	modeLabel.Size = UDim2.new(1, 0, 0, 18)
	modeLabel.BackgroundTransparency = 1
	modeLabel.Font = Enum.Font.Gotham
	modeLabel.TextSize = 14
	modeLabel.TextXAlignment = Enum.TextXAlignment.Left
	modeLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	modeLabel.Text = "Modus: Training"
	modeLabel.Parent = frame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.LayoutOrder = 3
	statsLabel.Size = UDim2.new(1, 0, 0, 54)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 14
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
	statsLabel.Text = "Wins: 0\nLosses: 0\nRank: 0"
	statsLabel.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "HintLabel"
	hint.LayoutOrder = 4
	hint.Size = UDim2.new(1, 0, 0, 36)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 12
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.TextColor3 = Color3.fromRGB(160, 170, 190)
	hint.TextWrapped = true
	hint.Text = "Laufe zu Arena, Bey Shop oder Ruhmeshalle."
	hint.Parent = frame

	return gui
end

local function updateHud(payload)
	if not use3DHub or not inHub then return end

	hideBattleUi()
	local gui = getOrCreateHud()
	local panel = gui.Panel

	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins or 0,
		payload.losses or 0,
		payload.rank or 0
	)
	gui.Enabled = true
end

local function setHubVisible(visible)
	local gui = playerGui:FindFirstChild("HubHUD")
	if gui then
		gui.Enabled = visible
	end
end

NovaBladers:GetAttributeChangedSignal("Use3DHub"):Connect(function()
	use3DHub = NovaBladers:GetAttribute("Use3DHub") == true
end)

Remotes.HubState.OnClientEvent:Connect(function(payload)
	if payload.use3DHub ~= nil then
		use3DHub = payload.use3DHub
	end
	inHub = payload.inHub ~= false

	if use3DHub and inHub then
		updateHud(payload)
	else
		setHubVisible(false)
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.use3DHub or use3DHub then
		use3DHub = true
		inHub = payload.inHub ~= false
		if inHub then
			updateHud(payload)
		end
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		hideBattleUi()
		select.Enabled = true
	end
end)
