local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui
local currentAction

local function ensureHintGui()
	if hintGui then
		return hintGui
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -120)
	frame.Size = UDim2.fromOffset(360, 72)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 32)
	title.Position = UDim2.fromOffset(8, 6)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -16, 0, 28)
	hint.Position = UDim2.fromOffset(8, 36)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 16
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	hintGui = screen
	return screen
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	local gui = ensureHintGui()
	local panel = gui.Panel

	if not payload then
		panel.Visible = false
		currentAction = nil
		return
	end

	currentAction = payload.action
	panel.Title.Text = payload.name
	panel.Hint.Text = payload.hint
	panel.Visible = true
end)

local function onActionInput(input, processed)
	if processed or not currentAction then
		return
	end

	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		Remotes.HubZoneAction:FireServer(currentAction)
	end
end

UserInputService.InputBegan:Connect(onActionInput)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
