local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZoneId = nil
local hintGui

local function getCharacterRoot()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function ensureHintGui()
	if hintGui then return hintGui end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HubZoneHint"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -80)
	frame.Size = UDim2.fromOffset(360, 72)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 28)
	title.Position = UDim2.fromOffset(8, 6)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -16, 0, 28)
	hint.Position = UDim2.fromOffset(8, 34)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 16
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	hintGui = screenGui
	return screenGui
end

local function showHint(zoneId, titleText, hintText)
	local gui = ensureHintGui()
	local panel = gui.Panel
	panel.Title.Text = titleText or ""
	panel.Hint.Text = hintText or ""
	panel.Visible = titleText ~= nil
	activeZoneId = zoneId
end

local function hideHint()
	if not hintGui then return end
	hintGui.Panel.Visible = false
	activeZoneId = nil
end

local function isInsideZone(rootPos, zone)
	local half = zone.size / 2
	local dx = math.abs(rootPos.X - zone.position.X)
	local dz = math.abs(rootPos.Z - zone.position.Z)
	return dx <= half.X and dz <= half.Z
end

local function updateNearestZone()
	local root = getCharacterRoot()
	if not root then
		hideHint()
		return
	end

	local nearestId = nil
	local nearestZone = nil
	local nearestDist = math.huge

	for zoneId, zone in HubConfig.ZONES do
		if isInsideZone(root.Position, zone) then
			local dist = (Vector3.new(zone.position.X, 0, zone.position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearestId = zoneId
				nearestZone = zone
			end
		end
	end

	if nearestZone then
		showHint(nearestId, nearestZone.name, nearestZone.hint)
	else
		hideHint()
	end
end

RunService.Heartbeat:Connect(updateNearestZone)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if not activeZoneId then return end
	Remotes.HubZoneAction:FireServer(activeZoneId)
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	showHint(payload.zoneId, payload.name, payload.hint)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
