local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local currentZoneId = nil
local hintVisible = false

local gui = Instance.new("ScreenGui")
gui.Name = "HubZoneHint"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 1, -80)
frame.Size = UDim2.fromOffset(320, 72)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -16, 0, 22)
hint.Position = UDim2.fromOffset(8, 34)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextColor3 = Color3.fromRGB(200, 200, 210)
hint.TextSize = 14
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

local action = Instance.new("TextLabel")
action.Name = "Action"
action.Size = UDim2.new(1, -16, 0, 18)
action.Position = UDim2.fromOffset(8, 52)
action.BackgroundTransparency = 1
action.Font = Enum.Font.GothamBold
action.TextColor3 = Color3.fromRGB(120, 200, 255)
action.TextSize = 14
action.TextXAlignment = Enum.TextXAlignment.Left
action.Parent = frame

local function showHint(zone)
	title.Text = zone.name
	hint.Text = zone.hint
	action.Text = zone.actionLabel or ""
	gui.Enabled = true
	hintVisible = true
end

local function hideHint()
	gui.Enabled = false
	hintVisible = false
	currentZoneId = nil
end

local function getNearestZone()
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local nearestZone = nil
	local nearestDist = HubConfig.HINT_RANGE

	for _, zone in HubConfig.ZONES do
		local dist = (root.Position - zone.position).Magnitude
		if dist <= nearestDist then
			nearestDist = dist
			nearestZone = zone
		end
	end

	return nearestZone
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	showHint(payload)
	if payload.zoneId then
		currentZoneId = payload.zoneId
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

RunService.Heartbeat:Connect(function()
	local zone = getNearestZone()
	if zone then
		if currentZoneId ~= zone.id then
			currentZoneId = zone.id
			showHint(zone)
		end
	else
		if hintVisible then
			hideHint()
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not currentZoneId then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		Remotes.HubZoneAction:FireServer(currentZoneId)
	end
end)
