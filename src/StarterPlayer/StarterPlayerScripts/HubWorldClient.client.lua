local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")
local HubConfig = require(NovaBladers.HubConfig)

local hintGui
local hintLabel

local function ensureHintGui()
	if hintGui then return end

	hintGui = Instance.new("ScreenGui")
	hintGui.Name = "HubZoneHint"
	hintGui.ResetOnSpawn = false
	hintGui.DisplayOrder = 5
	hintGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 12)
	frame.Size = UDim2.fromOffset(360, 48)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = hintGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.fromScale(1, 1)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.GothamMedium
	hintLabel.TextSize = 16
	hintLabel.TextColor3 = Color3.fromRGB(230, 235, 255)
	hintLabel.Parent = frame
end

local function showHint(text)
	ensureHintGui()
	hintLabel.Text = text
	hintGui.Banner.Visible = true
end

local function hideHint()
	if hintGui then
		hintGui.Banner.Visible = false
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(text)
	if text and text ~= "" then
		showHint(text)
	else
		hideHint()
	end
end)

local function findZoneById(zoneId)
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if not hub then return nil end
	local zones = hub:FindFirstChild("Zones")
	return zones and zones:FindFirstChild(zoneId)
end

local function wireZone(zoneDef)
	local part = findZoneById(zoneDef.id)
	if not part then return end

	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function()
		if zoneDef.action == "enterArena" then
			Remotes.EnterArena:FireServer()
		elseif zoneDef.action == "openBeySelect" then
			local beySelect = playerGui:FindFirstChild("BeySelect")
			if beySelect then
				beySelect.Enabled = true
			end
		elseif zoneDef.action == "hallOfFame" then
			showHint("🏆 Ruhmeshalle — Rangliste am Wand-Board")
		end
	end)

	part.Touched:Connect(function(hit)
		local character = hit.Parent
		if character ~= player.Character then return end
		showHint(zoneDef.hint)
	end)

	part.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		if character ~= player.Character then return end
		task.delay(0.5, hideHint)
	end)
end

local function connectZones()
	local hub = workspace:WaitForChild(HubConfig.HUB_NAME, 30)
	if not hub then return end
	for _, zoneDef in HubConfig.ZONES do
		wireZone(zoneDef)
	end
end

task.defer(connectZones)
