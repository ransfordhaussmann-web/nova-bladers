local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local remotes = NovaBladers:WaitForChild("Remotes")

local activeZone = nil
local promptGui = nil

local function getCharacterRoot()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function destroyPrompt()
	if promptGui then
		promptGui:Destroy()
		promptGui = nil
	end
end

local function showPrompt(zoneName, action)
	destroyPrompt()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HubZonePrompt"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.92, 0)
	frame.Size = UDim2.fromOffset(280, 56)
	frame.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	frame.BackgroundTransparency = 0.15
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.fromOffset(8, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(240, 240, 250)
	label.TextScaled = true
	label.Text = string.format("[E] %s", zoneName)
	label.Parent = frame

	promptGui = screenGui
	promptGui:SetAttribute("ZoneAction", action)
end

local function findZoneAtPosition(position)
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if not hub then return nil end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return nil end

	for _, zoneFolder in zones:GetChildren() do
		local trigger = zoneFolder:FindFirstChild("Trigger")
		if trigger and (trigger.Position - position).Magnitude <= HubConfig.ZONE_RADIUS then
			return trigger
		end
	end
	return nil
end

local function updateZone()
	local root = getCharacterRoot()
	if not root then
		activeZone = nil
		destroyPrompt()
		return
	end

	local trigger = findZoneAtPosition(root.Position)
	if not trigger then
		activeZone = nil
		destroyPrompt()
		return
	end

	local zoneId = trigger:GetAttribute("ZoneId")
	local action = trigger:GetAttribute("ZoneAction")
	if activeZone ~= zoneId then
		activeZone = zoneId
		local zoneConfig
		for _, config in HubConfig.ZONES do
			if config.id == zoneId then
				zoneConfig = config
				break
			end
		end
		if zoneConfig then
			showPrompt(zoneConfig.name, action)
		end
	end
end

local function tryInteract()
	if not promptGui then return end
	local action = promptGui:GetAttribute("ZoneAction")
	if typeof(action) ~= "string" then return end
	remotes.HubZoneAction:FireServer(action)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		tryInteract()
	end
end)

task.spawn(function()
	while true do
		updateZone()
		task.wait(0.2)
	end
end)

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local selectGui = player.PlayerGui:FindFirstChild("BeySelect")
	if selectGui then
		selectGui.Enabled = true
	end
end)
