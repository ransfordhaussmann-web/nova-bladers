local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.new(0, 420, 0, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Size = UDim2.fromScale(1, 1)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
hintLabel.TextSize = 18
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local hideToken = 0

local function showHint(text)
	hideToken += 1
	local token = hideToken
	hintLabel.Text = text
	hintGui.Enabled = true
	task.delay(4, function()
		if hideToken == token then
			hintGui.Enabled = false
		end
	end)
end

local zoneById = {}
for _, zone in HubConfig.ZONES do
	zoneById[zone.id] = zone
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	local zone = zoneById[payload.zoneId]
	if zone then
		showHint(zone.hint)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
