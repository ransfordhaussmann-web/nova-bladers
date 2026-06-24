local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil
local hintGui

local function ensureHintGui()
	if hintGui then return hintGui end

	hintGui = Instance.new("ScreenGui")
	hintGui.Name = "HubZoneHint"
	hintGui.ResetOnSpawn = false
	hintGui.Enabled = false
	hintGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -80)
	frame.Size = UDim2.fromOffset(320, 90)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = hintGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 32)
	title.Position = UDim2.fromOffset(8, 6)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Text = ""
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -16, 0, 24)
	hint.Position = UDim2.fromOffset(8, 38)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.fromRGB(220, 220, 230)
	hint.TextScaled = true
	hint.Font = Enum.Font.Gotham
	hint.Text = ""
	hint.Parent = frame

	local action = Instance.new("TextLabel")
	action.Name = "Action"
	action.Size = UDim2.new(1, -16, 0, 20)
	action.Position = UDim2.fromOffset(8, 64)
	action.BackgroundTransparency = 1
	action.TextColor3 = Color3.fromRGB(140, 200, 255)
	action.TextScaled = true
	action.Font = Enum.Font.GothamMedium
	action.Text = ""
	action.Parent = frame

	return hintGui
end

local function showZoneHint(payload)
	local gui = ensureHintGui()
	local panel = gui.Panel

	if not payload then
		currentZone = nil
		gui.Enabled = false
		return
	end

	currentZone = payload
	gui.Enabled = true
	panel.Title.Text = payload.name or ""
	panel.Hint.Text = payload.hint or ""
	if payload.action and payload.actionLabel then
		panel.Action.Text = string.format("[E] %s", payload.actionLabel)
	else
		panel.Action.Text = ""
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZoneHint)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not currentZone or not currentZone.action then return end
	if input.KeyCode ~= Enum.KeyCode.E and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	Remotes.HubZoneAction:FireServer(currentZone.action)
end)
