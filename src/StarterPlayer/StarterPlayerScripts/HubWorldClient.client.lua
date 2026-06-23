local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil
local inHub = true

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HubZoneUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -80)
hintFrame.Size = UDim2.new(0, 360, 0, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -16, 0, 28)
titleLabel.Position = UDim2.fromOffset(8, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -16, 0, 28)
hintLabel.Position = UDim2.fromOffset(8, 36)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 15
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintFrame

local function setHint(payload)
	if not payload then
		currentZone = nil
		screenGui.Enabled = false
		return
	end

	currentZone = payload
	screenGui.Enabled = true
	titleLabel.Text = payload.name or ""
	hintLabel.Text = payload.hint or ""
end

local function activateZone()
	if not currentZone or not currentZone.action then return end
	Remotes.HubZoneAction:FireServer({
		action = "ActivateZone",
		zoneId = currentZone.zoneId,
	})
end

Remotes.HubZoneHint.OnClientEvent:Connect(setHint)

Remotes.HubZoneAction.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.action == "LeftHub" then
		inHub = false
		screenGui.Enabled = false
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub then return end
	if input.KeyCode == Enum.KeyCode.E then
		activateZone()
	end
end)
