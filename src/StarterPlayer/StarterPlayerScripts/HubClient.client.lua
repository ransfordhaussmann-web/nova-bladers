local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.NovaBladers.HubWorldConfig)

local player = Players.LocalPlayer
local hintGui = nil
local lastZoneId = nil

local function getRootPart()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function ensureHintGui()
	if hintGui then return hintGui end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HubHints"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -24)
	label.Size = UDim2.fromOffset(420, 40)
	label.BackgroundColor3 = Color3.fromRGB(12, 16, 28)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(230, 235, 255)
	label.TextSize = 16
	label.TextTransparency = 1
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	hintGui = gui
	return gui
end

local function setHint(text, visible)
	local gui = ensureHintGui()
	local label = gui.HintLabel
	label.Text = text or ""
	label.TextTransparency = visible and 0 or 1
	label.BackgroundTransparency = visible and 0.25 or 1
end

local function findNearestZone(position)
	local nearest = nil
	local nearestDist = math.huge

	for _, zone in Config.ZONES do
		local dist = (Vector3.new(position.X, zone.position.Y, position.Z) - zone.position).Magnitude
		if dist <= zone.radius and dist < nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end

	return nearest
end

local function onHeartbeat()
	local root = getRootPart()
	if not root then
		setHint("", false)
		lastZoneId = nil
		return
	end

	local hub = workspace:FindFirstChild(Config.ROOT_NAME)
	if not hub then
		setHint("", false)
		return
	end

	local zone = findNearestZone(root.Position)
	if not zone then
		if lastZoneId then
			setHint("", false)
			lastZoneId = nil
		end
		return
	end

	if zone.id ~= lastZoneId then
		lastZoneId = zone.id
		local action = zone.id == "ArenaPortal" and " [E] Arena betreten" or " [E] Interagieren"
		setHint(zone.hint .. action, true)
	end
end

task.spawn(function()
	workspace:WaitForChild(Config.ROOT_NAME, 30)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < Config.PROXIMITY_CHECK_INTERVAL then return end
		accumulator = 0
		onHeartbeat()
	end)
end)
