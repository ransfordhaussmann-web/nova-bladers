local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZone = nil
local hintGui

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.92, 0)
	frame.Size = UDim2.new(0, 360, 0, 48)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamMedium
	label.Parent = frame

	hintGui = screen
	return screen
end

local function showHint(text)
	local gui = ensureHintGui()
	local banner = gui.Banner
	banner.Text.Text = text
	banner.Visible = text ~= nil
end

local function bindZoneTriggers()
	local hub = workspace:WaitForChild("NovaHub", 30)
	if not hub then return end

	local zones = hub:WaitForChild("Zones")
	for _, zoneFolder in zones:GetChildren() do
		local trigger = zoneFolder:FindFirstChild("Trigger")
		if not trigger then continue end

		local zoneId = zoneFolder.Name
		local zoneDef
		for _, z in HubConfig.ZONES do
			if z.id == zoneId then
				zoneDef = z
				break
			end
		end
		if not zoneDef then continue end

		trigger.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then return end
			local hum = character:FindFirstChildOfClass("Humanoid")
			if not hum or character ~= player.Character then return end
			activeZone = zoneId
			showHint(zoneDef.hint)
			Remotes.HubZoneHint:FireServer(zoneId)
		end)

		trigger.TouchEnded:Connect(function(hit)
			local character = hit.Parent
			if not character or character ~= player.Character then return end
			if activeZone == zoneId then
				activeZone = nil
				showHint(nil)
			end
		end)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if not activeZone then return end
	Remotes.HubZoneAction:FireServer(activeZone)
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(text)
	showHint(text)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

task.defer(bindZoneTriggers)
