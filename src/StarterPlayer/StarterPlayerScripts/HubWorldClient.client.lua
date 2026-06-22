local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZone = nil
local inHub = true

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
hintLabel.Size = UDim2.fromOffset(400, 44)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 18
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local function getHubOrigin()
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if hub and hub:GetAttribute("Origin") then
		return hub:GetAttribute("Origin")
	end
	return Vector3.new(0, 0, 200)
end

local function findNearestZone()
	local character = player.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local origin = getHubOrigin()
	local pos = hrp.Position
	local nearest = nil
	local nearestDist = HubConfig.ZONE_RADIUS

	for _, zone in HubConfig.ZONES do
		local zonePos = origin + zone.position
		local dist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(zonePos.X, 0, zonePos.Z)).Magnitude
		if dist <= nearestDist then
			nearestDist = dist
			nearest = zone
		end
	end

	return nearest
end

local function updateHint()
	if not inHub then
		hintGui.Enabled = false
		activeZone = nil
		return
	end

	local zone = findNearestZone()
	if zone then
		activeZone = zone
		hintLabel.Text = zone.hint
		hintGui.Enabled = true
	else
		activeZone = nil
		hintGui.Enabled = false
	end
end

RunService.Heartbeat:Connect(updateHint)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub or not activeZone then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	remotes.HubZoneAction:FireServer(activeZone.action)
end)

remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub ~= nil then
		inHub = payload.inHub
		if not inHub then
			hintGui.Enabled = false
			activeZone = nil
		end
	end
end)

remotes.ReturnToHub.OnClientEvent:Connect(function()
	inHub = true
end)
