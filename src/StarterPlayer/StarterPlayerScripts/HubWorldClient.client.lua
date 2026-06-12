local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

local HINT_RANGE = 14
local activeHint = nil

local function findHubZones()
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return nil end
	return hub:FindFirstChild("Zones")
end

local function getNearestZone(rootPos)
	local zones = findHubZones()
	if not zones then return nil, nil end

	local nearestId = nil
	local nearestDist = HINT_RANGE

	for _, zoneDef in HubConfig.ZONES do
		local pad = zones:FindFirstChild(zoneDef.id .. "Pad")
		if pad then
			local dist = (pad.Position - rootPos).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearestId = zoneDef.id
			end
		end
	end

	return nearestId, nearestDist
end

local function ensureHintGui()
	local gui = player.PlayerGui:FindFirstChild("HubHint")
	if gui then return gui end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubHint"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player.PlayerGui

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0.92, 0)
	label.Size = UDim2.new(0.5, 0, 0.06, 0)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Visible = false
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return gui
end

local function getZoneDef(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

local function showHint(zoneId)
	local gui = ensureHintGui()
	local label = gui.HintLabel
	local zoneDef = getZoneDef(zoneId)
	if not zoneDef then
		label.Visible = false
		return
	end

	label.Text = string.format("%s — %s", zoneDef.label, zoneDef.hint)
	label.Visible = true
	activeHint = zoneId
end

local function hideHint()
	local gui = player.PlayerGui:FindFirstChild("HubHint")
	if gui then
		gui.HintLabel.Visible = false
	end
	activeHint = nil
end

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		hideHint()
		return
	end

	local zoneId = getNearestZone(root.Position)
	if zoneId and zoneId ~= activeHint then
		showHint(zoneId)
	elseif not zoneId and activeHint then
		hideHint()
	end
end)

local hubHintRemote = Remotes:FindFirstChild("HubZoneHint")
if hubHintRemote then
	hubHintRemote.OnClientEvent:Connect(function(zoneId)
		showHint(zoneId)
		task.delay(2, function()
			if activeHint == zoneId then
				hideHint()
			end
		end)
	end)
end
