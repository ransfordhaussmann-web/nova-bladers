local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local inHub = false
local activeZone = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "Hint"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 0.92, 0)
hintFrame.Size = UDim2.new(0, 320, 0, 48)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 8)
hintCorner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.fromScale(1, 1)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextScaled = true
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.Parent = hintFrame

local zoneById = {}
for _, zone in HubConfig.ZONES do
	zoneById[zone.id] = zone
end

local function setActiveZone(zoneId)
	activeZone = zoneId
	if zoneId and zoneById[zoneId] then
		hintLabel.Text = zoneById[zoneId].hint
		hintGui.Enabled = true
	else
		hintGui.Enabled = false
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	if not inHub then
		setActiveZone(nil)
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(zoneId)
	if inHub then
		setActiveZone(zoneId)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local function fireZoneAction()
	if not inHub or not activeZone then
		return
	end
	local zone = zoneById[activeZone]
	if not zone then
		return
	end
	if zone.action == "enterArena" then
		Remotes.EnterArena:FireServer()
	elseif zone.action == "openBeySelect" then
		Remotes.OpenBeySelect:FireServer()
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		fireZoneAction()
	end
end)
