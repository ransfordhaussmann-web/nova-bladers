local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "Bar"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.fromOffset(360, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local hintTitle = Instance.new("TextLabel")
hintTitle.Name = "Title"
hintTitle.Size = UDim2.new(1, -16, 0, 22)
hintTitle.Position = UDim2.fromOffset(8, 6)
hintTitle.BackgroundTransparency = 1
hintTitle.Font = Enum.Font.GothamBold
hintTitle.TextColor3 = Color3.fromRGB(255, 220, 120)
hintTitle.TextSize = 16
hintTitle.TextXAlignment = Enum.TextXAlignment.Left
hintTitle.Parent = hintFrame

local hintText = Instance.new("TextLabel")
hintText.Name = "Hint"
hintText.Size = UDim2.new(1, -16, 0, 20)
hintText.Position = UDim2.fromOffset(8, 28)
hintText.BackgroundTransparency = 1
hintText.Font = Enum.Font.Gotham
hintText.TextColor3 = Color3.fromRGB(220, 225, 235)
hintText.TextSize = 14
hintText.TextXAlignment = Enum.TextXAlignment.Left
hintText.Parent = hintFrame

local inHub = true
local hintToken = 0

local function showHint(zoneName, text)
	hintToken += 1
	local token = hintToken
	hintTitle.Text = zoneName or "Nova Hub"
	hintText.Text = text or ""
	hintGui.Enabled = true
	task.delay(4, function()
		if token == hintToken then
			hintGui.Enabled = false
		end
	end)
end

local function getNearestZoneAction()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local nearestAction
	local nearestDist = math.huge
	for _, zone in HubConfig.ZONES do
		local zonePos = Vector3.new(zone.position.X, root.Position.Y, zone.position.Z)
		local dist = (root.Position - zonePos).Magnitude
		local radius = math.max(zone.size.X, zone.size.Z) * 0.55
		if dist <= radius and dist < nearestDist then
			nearestDist = dist
			nearestAction = zone.action
		end
	end
	return nearestAction
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	if not inHub then
		hintGui.Enabled = false
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(text, zoneName)
	if inHub then
		showHint(zoneName, text)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		local action = getNearestZoneAction()
		if action then
			Remotes.HubZoneAction:FireServer(action)
		end
	end
end)
