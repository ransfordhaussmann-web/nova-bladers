local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZoneAction
local hintGui

local function ensureHintGui()
	if hintGui then
		return hintGui
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HubZoneHint"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "HintFrame"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.92, 0)
	frame.Size = UDim2.fromOffset(360, 72)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 28)
	title.Position = UDim2.fromOffset(8, 6)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -16, 0, 28)
	hint.Position = UDim2.fromOffset(8, 34)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.fromRGB(220, 228, 245)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 16
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	hintGui = screenGui
	return screenGui
end

local function showHint(payload)
	local gui = ensureHintGui()
	local frame = gui.HintFrame
	if payload.clear then
		frame.Visible = false
		currentZoneAction = nil
		return
	end

	currentZoneAction = payload.action
	frame.Title.Text = payload.name or ""
	frame.Hint.Text = payload.hint or ""
	frame.Visible = true
end

local function tryZoneAction()
	if not currentZoneAction then
		return
	end
	remotes.HubZoneAction:FireServer(currentZoneAction)
end

remotes.HubZoneHint.OnClientEvent:Connect(showHint)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == HubConfig.ZONE_ACTION_KEY then
		tryZoneAction()
	end
end)
