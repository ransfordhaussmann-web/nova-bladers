local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil

local function getOrCreateHintGui()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("HubZoneHint")
	if existing then return existing end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HubZoneHint"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -80)
	frame.Size = UDim2.new(0, 320, 0, 90)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -20, 0, 24)
	hint.Position = UDim2.new(0, 10, 0, 44)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(180, 190, 210)
	hint.TextSize = 16
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	local action = Instance.new("TextLabel")
	action.Name = "Action"
	action.Size = UDim2.new(1, -20, 0, 20)
	action.Position = UDim2.new(0, 10, 0, 66)
	action.BackgroundTransparency = 1
	action.Font = Enum.Font.GothamBold
	action.TextColor3 = Color3.fromRGB(120, 200, 255)
	action.TextSize = 14
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.Parent = frame

	return gui
end

local hintGui = getOrCreateHintGui()
local panel = hintGui.Panel

local function showZoneHint(payload)
	if not payload then
		currentZone = nil
		hintGui.Enabled = false
		return
	end

	currentZone = payload.zoneId
	panel.Title.Text = payload.name
	panel.Hint.Text = payload.hint
	panel.Action.Text = "[E] " .. (payload.actionLabel or "Interagieren")
	hintGui.Enabled = true
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZoneHint)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if not currentZone then return end
	Remotes.HubZoneAction:FireServer(currentZone)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
