local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local inHub = true
local currentZone = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Size = UDim2.fromOffset(360, 56)
hintFrame.Position = UDim2.new(0.5, -180, 1, -90)
hintFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 10)
hintCorner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -16, 1, 0)
hintLabel.Position = UDim2.fromOffset(8, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextSize = 16
hintLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local function isPointInZone(position, zone)
	local half = zone.size / 2
	local min = zone.center - half
	local max = zone.center + half
	return position.X >= min.X and position.X <= max.X
		and position.Y >= min.Y and position.Y <= max.Y
		and position.Z >= min.Z and position.Z <= max.Z
end

local function findZoneAt(position)
	for _, zone in HubConfig.ZONES do
		if isPointInZone(position, zone) then
			return zone
		end
	end
	return nil
end

local function updateHint(zone)
	if zone and zone.action ~= "none" then
		hintLabel.Text = string.format("[%s]  %s", zone.name, zone.hint)
		hintGui.Enabled = true
	elseif zone then
		hintLabel.Text = string.format("[%s]  %s", zone.name, zone.hint)
		hintGui.Enabled = true
	else
		hintGui.Enabled = false
	end
end

local function tryZoneAction()
	if not inHub or not currentZone or currentZone.action == "none" then
		return
	end
	Remotes.HubZoneAction:FireServer(currentZone.id)
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub ~= false
	if not inHub then
		hintGui.Enabled = false
		currentZone = nil
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)

RunService.Heartbeat:Connect(function()
	if not inHub then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local zone = findZoneAt(root.Position)
	if zone ~= currentZone then
		currentZone = zone
		updateHint(zone)
	end
end)
