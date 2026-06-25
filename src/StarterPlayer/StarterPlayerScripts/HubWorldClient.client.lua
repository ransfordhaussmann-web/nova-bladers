local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZoneId = nil
local interactGui

local function ensureHintGui()
	if interactGui then
		return interactGui
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HubHint"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "HintFrame"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.92, 0)
	frame.Size = UDim2.fromOffset(420, 44)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 16
	label.Text = ""
	label.Parent = frame

	interactGui = gui
	return gui
end

local function setHint(zoneId)
	local gui = ensureHintGui()
	local frame = gui.HintFrame
	local zone = HubConfig.ZONES[zoneId]

	if zone then
		frame.HintLabel.Text = zone.hint
		frame.Visible = true
		currentZoneId = zoneId
	else
		frame.Visible = false
		currentZoneId = nil
	end
end

local function getCharacterPosition()
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return root.Position
end

local function findNearestZone(position)
	local bestId = nil
	local bestDist = math.huge

	for zoneId, zone in HubConfig.ZONES do
		local half = zone.size / 2
		local min = zone.position - half
		local max = zone.position + half
		local inside = position.X >= min.X and position.X <= max.X
			and position.Y >= min.Y and position.Y <= max.Y
			and position.Z >= min.Z and position.Z <= max.Z
		if inside then
			return zoneId
		end

		local dist = (Vector3.new(zone.position.X, position.Y, zone.position.Z) - position).Magnitude
		if dist < bestDist and dist <= math.max(half.X, half.Z) + 4 then
			bestDist = dist
			bestId = zoneId
		end
	end

	return bestId
end

RunService.Heartbeat:Connect(function()
	if player:GetAttribute("InArena") == true then
		if currentZoneId then
			setHint(nil)
		end
		return
	end

	local position = getCharacterPosition()
	if not position then
		return
	end

	local zoneId = findNearestZone(position)
	if zoneId ~= currentZoneId then
		setHint(zoneId)
	end
end)

local function tryInteract()
	if player:GetAttribute("InArena") == true or not currentZoneId then
		return
	end
	Remotes.HubInteract:FireServer(currentZoneId)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		tryInteract()
	end
end)
