local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local activeZoneId = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -80)
hintLabel.Size = UDim2.fromOffset(420, 48)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
hintLabel.BackgroundTransparency = 0.2
hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextSize = 18
hintLabel.Text = ""
hintLabel.Parent = hintGui

local function getCharacterPosition()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	return root.Position
end

local function findNearestZone(position)
	local nearestId = nil
	local nearestDist = math.huge

	for _, zone in pairs(HubConfig.ZONES) do
		local half = zone.size / 2
		local min = zone.position - half
		local max = zone.position + half
		if position.X >= min.X and position.X <= max.X
			and position.Y >= min.Y and position.Y <= max.Y
			and position.Z >= min.Z and position.Z <= max.Z then
			return zone.id, zone
		end

		local dist = (Vector3.new(zone.position.X, position.Y, zone.position.Z) - position).Magnitude
		if dist < nearestDist and dist <= math.max(half.X, half.Z) + 2 then
			nearestDist = dist
			nearestId = zone.id
		end
	end

	if nearestId then
		for _, zone in pairs(HubConfig.ZONES) do
			if zone.id == nearestId then
				return zone.id, zone
			end
		end
	end
	return nil, nil
end

local function updateZoneHint()
	if not inHub then
		hintGui.Enabled = false
		activeZoneId = nil
		return
	end

	local position = getCharacterPosition()
	if not position then return end

	local zoneId, zone = findNearestZone(position)
	activeZoneId = zoneId

	if zone then
		hintLabel.Text = string.format("[%s] %s", zone.name, zone.hint)
		hintGui.Enabled = true
	else
		hintGui.Enabled = false
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub == false then
		inHub = false
		hintGui.Enabled = false
		activeZoneId = nil
	else
		inHub = true
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub or not activeZoneId then return end
	if input.KeyCode == Enum.KeyCode.E then
		Remotes.HubZoneAction:FireServer(activeZoneId)
	end
end)

task.spawn(function()
	while true do
		updateZoneHint()
		task.wait(0.15)
	end
end)
