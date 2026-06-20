local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZoneId = nil
local promptGui = nil

local function getCharacterRoot()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function getNearestZone()
	local root = getCharacterRoot()
	if not root then return nil end

	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return nil end

	local zones = hub:FindFirstChild("Zones")
	if not zones then return nil end

	local nearestId = nil
	local nearestDist = HubConfig.INTERACT_RANGE

	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			local dist = (zonePart.Position - root.Position).Magnitude
			if dist <= nearestDist then
				nearestDist = dist
				nearestId = zonePart:GetAttribute("ZoneId")
			end
		end
	end

	return nearestId
end

local function ensurePromptGui()
	if promptGui then return promptGui end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HubPrompt"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "Hint"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0.92, 0)
	label.Size = UDim2.fromOffset(360, 44)
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 18
	label.Text = ""
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	promptGui = gui
	return gui
end

local function updatePrompt()
	local gui = ensurePromptGui()
	local zoneId = getNearestZone()
	activeZoneId = zoneId

	if not zoneId then
		gui.Enabled = false
		return
	end

	local zone = HubConfig.ZONES[zoneId]
	if not zone then
		gui.Enabled = false
		return
	end

	gui.Hint.Text = string.format("[%s] %s — %s", HubConfig.PROMPT_KEY.Name, zone.label, zone.hint)
	gui.Enabled = true
end

local function tryInteract()
	if not activeZoneId then return end
	remotes.HubZoneAction:FireServer(activeZoneId)
end

RunService.Heartbeat:Connect(updatePrompt)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == HubConfig.PROMPT_KEY then
		tryInteract()
	end
end)

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
