local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local ACTION_KEY = Enum.KeyCode.E

local hintGui
local hintLabel
local actionLabel
local activeAction

local function ensureHintGui()
	if hintGui then return end

	hintGui = Instance.new("ScreenGui")
	hintGui.Name = "HubZoneHint"
	hintGui.ResetOnSpawn = false
	hintGui.Enabled = false
	hintGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -80)
	frame.Size = UDim2.fromOffset(320, 72)
	frame.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = hintGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -16, 0, 28)
	hintLabel.Position = UDim2.fromOffset(8, 8)
	hintLabel.BackgroundTransparency = 1
	hintLabel.TextColor3 = Color3.fromRGB(230, 235, 255)
	hintLabel.Font = Enum.Font.GothamBold
	hintLabel.TextSize = 18
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Parent = frame

	actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "Action"
	actionLabel.Size = UDim2.new(1, -16, 0, 24)
	actionLabel.Position = UDim2.fromOffset(8, 38)
	actionLabel.BackgroundTransparency = 1
	actionLabel.TextColor3 = Color3.fromRGB(160, 180, 220)
	actionLabel.Font = Enum.Font.Gotham
	actionLabel.TextSize = 15
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.Parent = frame
end

local function showHint(payload)
	ensureHintGui()
	if payload.clear then
		hintGui.Enabled = false
		activeAction = nil
		return
	end

	activeAction = payload.action
	hintLabel.Text = payload.name or "Zone"
	actionLabel.Text = string.format("[E] %s", payload.hint or "Interagieren")
	hintGui.Enabled = true
end

local function tryZoneAction()
	if not activeAction then return end
	Remotes.HubZoneAction:FireServer(activeAction)
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == ACTION_KEY then
		tryZoneAction()
	end
end)

-- Mobile: tap hint panel to trigger zone action
ensureHintGui()
hintGui.Panel.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		tryZoneAction()
	end
end)
