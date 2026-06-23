local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil
local hintGui = nil

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -80)
	frame.Size = UDim2.new(0, 320, 0, 64)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ZoneName"
	nameLabel.Size = UDim2.new(1, -16, 0, 28)
	nameLabel.Position = UDim2.fromOffset(8, 6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = frame

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -16, 0, 22)
	hintLabel.Position = UDim2.fromOffset(8, 34)
	hintLabel.BackgroundTransparency = 1
	hintLabel.TextColor3 = Color3.new(1, 1, 1)
	hintLabel.TextScaled = true
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.Parent = frame

	hintGui = screen
	return screen
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	local gui = ensureHintGui()
	local panel = gui.Panel

	if not payload.zoneId then
		currentZone = nil
		panel.Visible = false
		return
	end

	currentZone = payload.zoneId
	panel.ZoneName.Text = payload.name or ""
	panel.Hint.Text = payload.hint or ""
	panel.Visible = true
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if not currentZone then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	Remotes.HubZoneAction:FireServer(currentZone)
end)
