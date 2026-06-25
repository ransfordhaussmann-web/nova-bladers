local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local currentZoneId = nil

local gui = Instance.new("ScreenGui")
gui.Name = "HubZoneHint"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -80)
hintLabel.Size = UDim2.fromOffset(420, 44)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 18
hintLabel.Text = ""
hintLabel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local function getNearestZone()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local nearest = nil
	local nearestDist = HubConfig.ZONE_HINT_DISTANCE

	for _, zone in HubConfig.ZONES do
		local dist = (root.Position - zone.position).Magnitude
		if dist <= nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end

	return nearest
end

local function updateHint()
	if not inHub then
		gui.Enabled = false
		currentZoneId = nil
		return
	end

	local zone = getNearestZone()
	if zone then
		currentZoneId = zone.id
		hintLabel.Text = zone.hint
		gui.Enabled = true
	else
		currentZoneId = nil
		gui.Enabled = false
	end
end

remotes.HubState.OnClientEvent:Connect(function(location)
	inHub = location == "hub"
	if not inHub then
		gui.Enabled = false
		currentZoneId = nil
	end
end)

player:GetAttributeChangedSignal("NovaBladersLocation"):Connect(function()
	inHub = player:GetAttribute("NovaBladersLocation") == "hub"
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub or not currentZoneId then return end
	if input.KeyCode == Enum.KeyCode.E then
		remotes.HubInteract:FireServer(currentZoneId)
	end
end)

RunService.Heartbeat:Connect(updateHint)
