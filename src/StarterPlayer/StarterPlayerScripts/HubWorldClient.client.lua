local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = NovaBladers:WaitForChild("Remotes")

local inHub = true
local activeZone = nil

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
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hintLabel.TextSize = 18
hintLabel.Text = ""
hintLabel.Parent = hintGui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 8)
hintCorner.Parent = hintLabel

local function getRootPosition()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function findNearestZone(position)
	local nearest = nil
	local nearestDist = HubConfig.ZONE_HINT_RANGE
	for _, zone in HubConfig.ZONES do
		local dist = (Vector3.new(position.X, zone.position.Y, position.Z) - zone.position).Magnitude
		if dist <= nearestDist then
			nearestDist = dist
			nearest = zone
		end
	end
	return nearest
end

local function updateZoneHint()
	if not inHub then
		hintGui.Enabled = false
		activeZone = nil
		return
	end

	local pos = getRootPosition()
	if not pos then return end

	local zone = findNearestZone(pos)
	if zone then
		activeZone = zone
		hintLabel.Text = zone.hint
		hintGui.Enabled = true
	else
		activeZone = nil
		hintGui.Enabled = false
	end
end

remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	if not inHub then
		hintGui.Enabled = false
		activeZone = nil
	end
end)

remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload.hint then
		hintLabel.Text = payload.hint
		hintGui.Enabled = true
		task.delay(4, function()
			if inHub then
				updateZoneHint()
			end
		end)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub or not activeZone then return end
	if input.KeyCode == HubConfig.ACTION_KEY then
		remotes.HubZoneAction:FireServer(activeZone.action)
	end
end)

RunService.Heartbeat:Connect(updateZoneHint)
