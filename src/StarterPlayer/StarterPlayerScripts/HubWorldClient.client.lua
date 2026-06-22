local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZone = nil
local hintGui

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "HintFrame"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.92, 0)
	frame.Size = UDim2.fromOffset(360, 48)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(240, 240, 250)
	label.Parent = frame

	hintGui = screen
	return screen
end

local function showHint(text)
	local gui = ensureHintGui()
	local frame = gui.HintFrame
	frame.HintLabel.Text = text or ""
	frame.Visible = text ~= nil and text ~= ""
end

local function getPlayerPosition()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function isInsideZone(position, zone)
	local half = zone.size / 2
	local min = zone.position - half
	local max = zone.position + half
	return position.X >= min.X and position.X <= max.X
		and position.Y >= min.Y and position.Y <= max.Y
		and position.Z >= min.Z and position.Z <= max.Z
end

local function findZoneAt(position)
	for _, zone in HubConfig.ZONES do
		if isInsideZone(position, zone) then
			return zone
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	local position = getPlayerPosition()
	if not position then
		if activeZone then
			activeZone = nil
			showHint(nil)
		end
		return
	end

	local zone = findZoneAt(position)
	if zone ~= activeZone then
		activeZone = zone
		if zone then
			showHint(zone.hint)
		else
			showHint(nil)
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if not activeZone or activeZone.action == "none" then return end
	remotes.HubZoneAction:FireServer(activeZone.action)
end)

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
