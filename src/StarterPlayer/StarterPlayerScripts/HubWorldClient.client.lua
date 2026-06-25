local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = false
local currentHint = ""

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
hintLabel.Size = UDim2.fromOffset(400, 40)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 18
hintLabel.Text = ""
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local function setInHub(value)
	inHub = value
	hintGui.Enabled = value
	if not value then
		currentHint = ""
		hintLabel.Text = ""
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	setInHub(payload.inHub == true)
end)

local function getNearestZone(position)
	local nearest
	local nearestDist = HubConfig.INTERACT_RADIUS
	for _, zone in HubConfig.ZONES do
		local dist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(zone.position.X, 0, zone.position.Z)).Magnitude
		if dist <= nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end
	return nearest
end

RunService.Heartbeat:Connect(function()
	if not inHub then return end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		if currentHint ~= "" then
			currentHint = ""
			hintLabel.Text = ""
		end
		return
	end

	local zone = getNearestZone(root.Position)
	local hint = zone and zone.hint or ""
	if hint ~= currentHint then
		currentHint = hint
		hintLabel.Text = hint
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	Remotes.HubInteract:FireServer()
end)
