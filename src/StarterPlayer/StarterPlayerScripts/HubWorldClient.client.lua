local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZoneId = nil
local hintGui

local function ensureHintGui()
	if hintGui then return hintGui end

	hintGui = Instance.new("ScreenGui")
	hintGui.Name = "HubZoneHint"
	hintGui.ResetOnSpawn = false
	hintGui.DisplayOrder = 5
	hintGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -24)
	frame.Size = UDim2.fromOffset(320, 72)
	frame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = hintGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 160, 255)
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -16, 0.45, 0)
	nameLabel.Position = UDim2.fromOffset(8, 6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 18
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = frame

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HintLabel"
	hintLabel.Size = UDim2.new(1, -16, 0.55, 0)
	hintLabel.Position = UDim2.new(0, 8, 0.45, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextSize = 15
	hintLabel.TextColor3 = Color3.fromRGB(190, 200, 220)
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Parent = frame

	return hintGui
end

local function showHint(payload)
	local gui = ensureHintGui()
	local panel = gui.Panel

	if not payload then
		panel.Visible = false
		currentZoneId = nil
		return
	end

	currentZoneId = payload.zoneId
	panel.NameLabel.Text = payload.name
	panel.HintLabel.Text = payload.actionLabel or payload.hint
	panel.Visible = true
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local function tryZoneAction()
	if not currentZoneId then return end
	Remotes.HubZoneAction:FireServer(currentZoneId)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)

-- Mobile: tap hint panel to interact
task.defer(function()
	local gui = ensureHintGui()
	gui.Panel.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			tryZoneAction()
		end
	end)
end)
