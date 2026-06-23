local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZoneKey = nil

local function hideBattleUi()
	local hud = playerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = playerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = playerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local hubGui = Instance.new("ScreenGui")
hubGui.Name = "HubWorldUI"
hubGui.ResetOnSpawn = false
hubGui.DisplayOrder = 5
hubGui.Parent = playerGui

local statsFrame = Instance.new("Frame")
statsFrame.Name = "StatsPanel"
statsFrame.Size = UDim2.fromOffset(200, 90)
statsFrame.Position = UDim2.new(0, 16, 0, 16)
statsFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
statsFrame.BackgroundTransparency = 0.25
statsFrame.BorderSizePixel = 0
statsFrame.Parent = hubGui

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 8)
statsCorner.Parent = statsFrame

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "StatsLabel"
statsLabel.Size = UDim2.new(1, -16, 1, -12)
statsLabel.Position = UDim2.fromOffset(8, 6)
statsLabel.BackgroundTransparency = 1
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 16
statsLabel.TextColor3 = Color3.fromRGB(220, 225, 240)
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = ""
statsLabel.Parent = statsFrame

local hintFrame = Instance.new("Frame")
hintFrame.Name = "ZoneHint"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.fromOffset(420, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
hintFrame.BackgroundTransparency = 0.2
hintFrame.Visible = false
hintFrame.Parent = hubGui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 10)
hintCorner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -20, 1, 0)
hintLabel.Position = UDim2.fromOffset(10, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextSize = 18
hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "ModeLabel"
modeLabel.AnchorPoint = Vector2.new(0.5, 0)
modeLabel.Position = UDim2.new(0.5, 0, 0, 16)
modeLabel.Size = UDim2.fromOffset(300, 28)
modeLabel.BackgroundTransparency = 1
modeLabel.Font = Enum.Font.GothamBold
modeLabel.TextSize = 18
modeLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
modeLabel.Text = ""
modeLabel.Parent = hubGui

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if not payload.inHub then
		hubGui.Enabled = false
		return
	end

	hideBattleUi()
	hubGui.Enabled = true
	statsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	modeLabel.Text = payload.modeLabel or "Modus: Training"
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload.inArena then
		currentZoneKey = nil
		hintFrame.Visible = false
		hubGui.Enabled = false
		return
	end

	if payload.zoneId == nil then
		currentZoneKey = nil
		hintFrame.Visible = false
		return
	end

	currentZoneKey = payload.zoneKey
	hintLabel.Text = string.format("[%s] %s", payload.label, payload.hint)
	hintFrame.Visible = true
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local function tryZoneAction()
	if currentZoneKey then
		Remotes.HubZoneAction:FireServer(currentZoneKey)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)
