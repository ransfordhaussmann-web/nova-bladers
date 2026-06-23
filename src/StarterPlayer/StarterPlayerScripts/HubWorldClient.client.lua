local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local currentZone = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
hintLabel.Size = UDim2.fromOffset(420, 44)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 18
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local function getCharacterPosition()
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function findNearestZone(position)
	local nearest = nil
	local nearestDist = HubConfig.INTERACT_RANGE

	for _, zone in HubConfig.ZONES do
		local dist = (position - zone.position).Magnitude
		if dist <= nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end

	return nearest
end

local function updateZoneHint()
	if not inHub then
		hintGui.Enabled = false
		currentZone = nil
		return
	end

	local pos = getCharacterPosition()
	if not pos then
		hintGui.Enabled = false
		return
	end

	local zone = findNearestZone(pos)
	if zone then
		currentZone = zone
		hintLabel.Text = string.format("%s — %s", zone.name, zone.hint)
		hintGui.Enabled = true
		Remotes.HubZoneHint:FireServer(zone.id)
	else
		currentZone = nil
		hintGui.Enabled = false
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub ~= false
	if not inHub then
		hintGui.Enabled = false
		currentZone = nil
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub or not currentZone then
		return
	end
	if input.KeyCode ~= HubConfig.INTERACT_KEY then
		return
	end
	if currentZone.action == "none" then
		return
	end
	Remotes.HubZoneAction:FireServer(currentZone.action)
end)

task.spawn(function()
	while true do
		updateZoneHint()
		task.wait(0.25)
	end
end)
