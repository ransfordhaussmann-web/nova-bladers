local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local playerGui = player:WaitForChild("PlayerGui")

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.DisplayOrder = 5
hintGui.Parent = playerGui

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -80)
hintFrame.Size = UDim2.fromOffset(360, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Visible = false
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.fromOffset(12, 8)
titleLabel.Size = UDim2.new(1, -24, 0, 22)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.BackgroundTransparency = 1
hintLabel.Position = UDim2.fromOffset(12, 30)
hintLabel.Size = UDim2.new(1, -24, 1, -38)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
hintLabel.TextSize = 14
hintLabel.TextWrapped = true
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextYAlignment = Enum.TextYAlignment.Top
hintLabel.Parent = hintFrame

local currentPersistent = false

local function showHint(zoneName, hint, persistent)
	if not hint or hint == "" then
		if not currentPersistent or persistent == false then
			hintFrame.Visible = false
			currentPersistent = false
		end
		return
	end

	titleLabel.Text = zoneName or "Nova Hub"
	hintLabel.Text = hint
	hintFrame.Visible = true
	currentPersistent = persistent == true

	if not persistent then
		hintFrame.Size = UDim2.fromOffset(360, 72)
	else
		local lineCount = select(2, hint:gsub("\n", "\n")) + 1
		hintFrame.Size = UDim2.fromOffset(360, math.max(72, 24 + lineCount * 18))
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	showHint(payload.zoneName, payload.hint, payload.persistent)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= HubConfig.INTERACT_KEY then return end
	if not hintFrame.Visible and not currentPersistent then return end
	Remotes.HubInteract:FireServer()
end)
