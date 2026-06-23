local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZone = nil
local hintGui
local statsGui

local function ensureStatsGui()
	if statsGui then
		return statsGui
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubStats"
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "Stats"
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.new(0, 12, 0, 12)
	label.Size = UDim2.new(0, 200, 0, 80)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(220, 225, 240)
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	statsGui = screen
	return screen
end

local function updateHubStats(payload)
	local gui = ensureStatsGui()
	gui.Stats.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d\n%s",
		payload.wins or 0,
		payload.losses or 0,
		payload.rank or 0,
		payload.modeLabel or ""
	)
	gui.Enabled = payload.inHub == true
end

Remotes.LobbyReady.OnClientEvent:Connect(updateHubStats)

local function ensureHintGui()
	if hintGui then
		return hintGui
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -80)
	frame.Size = UDim2.new(0, 320, 0, 72)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 28)
	title.Position = UDim2.new(0, 8, 0, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -16, 0, 22)
	hint.Position = UDim2.new(0, 8, 0, 36)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(180, 190, 210)
	hint.TextSize = 14
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	hintGui = screen
	return screen
end

local function showZoneHint(zone)
	local gui = ensureHintGui()
	gui.Enabled = true
	gui.Panel.Title.Text = zone.name
	gui.Panel.Hint.Text = zone.hint .. "  [E]"
	activeZone = zone
end

local function hideZoneHint()
	if hintGui then
		hintGui.Enabled = false
	end
	activeZone = nil
end

local function getPlayerPosition()
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

RunService.Heartbeat:Connect(function()
	local position = getPlayerPosition()
	if not position then
		hideZoneHint()
		return
	end

	local nearestZone = nil
	local nearestDist = HubConfig.INTERACT_DISTANCE

	for _, zone in HubConfig.ZONES do
		local dist = (position - zone.position).Magnitude
		if dist <= nearestDist then
			nearestDist = dist
			nearestZone = zone
		end
	end

	if nearestZone then
		if activeZone ~= nearestZone then
			showZoneHint(nearestZone)
		end
	else
		hideZoneHint()
	end
end)

local function triggerZoneAction()
	if not activeZone then
		return
	end
	Remotes.HubZoneAction:FireServer(activeZone.action)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		triggerZoneAction()
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
