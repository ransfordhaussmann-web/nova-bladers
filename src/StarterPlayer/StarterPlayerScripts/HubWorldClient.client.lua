local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil
local inHub = true

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HubWorldUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "ZoneHint"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -120)
hintFrame.Size = UDim2.fromOffset(360, 90)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
hintFrame.BackgroundTransparency = 0.15
hintFrame.Visible = false
hintFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local zoneLabel = Instance.new("TextLabel")
zoneLabel.Name = "ZoneName"
zoneLabel.Size = UDim2.new(1, -20, 0, 32)
zoneLabel.Position = UDim2.fromOffset(10, 8)
zoneLabel.BackgroundTransparency = 1
zoneLabel.Font = Enum.Font.GothamBold
zoneLabel.TextSize = 20
zoneLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
zoneLabel.TextXAlignment = Enum.TextXAlignment.Left
zoneLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -20, 0, 22)
hintLabel.Position = UDim2.fromOffset(10, 38)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 16
hintLabel.TextColor3 = Color3.fromRGB(180, 185, 200)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintFrame

local actionLabel = Instance.new("TextLabel")
actionLabel.Name = "Action"
actionLabel.Size = UDim2.new(1, -20, 0, 22)
actionLabel.Position = UDim2.fromOffset(10, 60)
actionLabel.BackgroundTransparency = 1
actionLabel.Font = Enum.Font.GothamMedium
actionLabel.TextSize = 16
actionLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
actionLabel.TextXAlignment = Enum.TextXAlignment.Left
actionLabel.Parent = hintFrame

local function setHintVisible(visible)
	hintFrame.Visible = visible and inHub
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub ~= false
	setHintVisible(currentZone ~= nil)
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(zoneData)
	if zoneData then
		currentZone = zoneData
		zoneLabel.Text = zoneData.name
		hintLabel.Text = zoneData.hint
		actionLabel.Text = zoneData.actionLabel or ""
		setHintVisible(true)
	else
		currentZone = nil
		setHintVisible(false)
	end
end)

local function fireZoneAction()
	if not inHub or not currentZone then return end
	Remotes.HubZoneAction:FireServer(currentZone.action)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		fireZoneAction()
	end
end)

-- Mobile: tap hint bar to trigger zone action
hintFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1 then
		fireZoneAction()
	end
end)
