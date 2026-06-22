local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local remotes = NovaBladers:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentZone = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = playerGui

local hintFrame = Instance.new("Frame")
hintFrame.Name = "Panel"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 0.92, 0)
hintFrame.Size = UDim2.fromOffset(360, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local zoneLabel = Instance.new("TextLabel")
zoneLabel.Name = "ZoneName"
zoneLabel.Size = UDim2.new(1, -20, 0.5, 0)
zoneLabel.Position = UDim2.fromOffset(10, 6)
zoneLabel.BackgroundTransparency = 1
zoneLabel.Font = Enum.Font.GothamBold
zoneLabel.TextSize = 18
zoneLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
zoneLabel.TextXAlignment = Enum.TextXAlignment.Left
zoneLabel.Parent = hintFrame

local actionLabel = Instance.new("TextLabel")
actionLabel.Name = "ActionHint"
actionLabel.Size = UDim2.new(1, -20, 0.5, -6)
actionLabel.Position = UDim2.fromOffset(10, 36)
actionLabel.BackgroundTransparency = 1
actionLabel.Font = Enum.Font.Gotham
actionLabel.TextSize = 15
actionLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
actionLabel.TextXAlignment = Enum.TextXAlignment.Left
actionLabel.Parent = hintFrame

local function showHint(payload)
	if not payload then
		currentZone = nil
		hintGui.Enabled = false
		return
	end

	currentZone = payload
	zoneLabel.Text = payload.name or ""
	actionLabel.Text = payload.hint or ""
	hintGui.Enabled = true
end

remotes.HubZoneHint.OnClientEvent:Connect(showHint)

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= HubConfig.ACTION_KEY then return end
	if not currentZone then return end

	remotes.HubZoneAction:FireServer(currentZone.zoneId)
end)
