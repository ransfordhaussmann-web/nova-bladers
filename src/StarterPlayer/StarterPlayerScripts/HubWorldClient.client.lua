local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local inHub = false
local canInteract = false

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = playerGui

local hintFrame = Instance.new("Frame")
hintFrame.Name = "Panel"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -120)
hintFrame.Size = UDim2.fromOffset(320, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -16, 0, 28)
titleLabel.Position = UDim2.fromOffset(8, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = ""
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -16, 0, 24)
hintLabel.Position = UDim2.fromOffset(8, 36)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
hintLabel.TextSize = 14
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Text = ""
hintLabel.Parent = hintFrame

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if not payload.visible then
		hintGui.Enabled = false
		canInteract = false
		return
	end

	inHub = true
	canInteract = payload.canInteract == true
	hintGui.Enabled = true
	titleLabel.Text = payload.label or ""
	hintLabel.Text = payload.hint or ""
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	if not inHub then
		hintGui.Enabled = false
		canInteract = false
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub or not canInteract then return end
	if input.KeyCode == HubConfig.INTERACT_KEY then
		Remotes.HubInteract:FireServer()
	end
end)
