local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZoneId = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HubZoneHint"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
hintLabel.Size = UDim2.fromOffset(360, 44)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.2
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 20
hintLabel.Font = Enum.Font.GothamBold
hintLabel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintLabel

remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload.visible then
		activeZoneId = payload.zoneId
		local key = payload.key or "E"
		hintLabel.Text = string.format("[%s] %s", key, payload.hint or "")
		screenGui.Enabled = true
	else
		activeZoneId = nil
		screenGui.Enabled = false
	end
end)

local function tryZoneAction()
	if not activeZoneId then return end
	remotes.HubZoneAction:FireServer(activeZoneId)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == HubConfig.ZONE_ACTION_KEY then
		tryZoneAction()
	end
end)
