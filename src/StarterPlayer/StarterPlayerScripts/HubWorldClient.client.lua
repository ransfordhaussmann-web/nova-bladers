local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui
local currentZone

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
	frame.Size = UDim2.fromOffset(320, 90)
	frame.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 28)
	title.Position = UDim2.fromOffset(8, 6)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(120, 200, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -16, 0, 22)
	hint.Position = UDim2.fromOffset(8, 36)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextSize = 16
	hint.Font = Enum.Font.Gotham
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	local actionBtn = Instance.new("TextButton")
	actionBtn.Name = "ActionButton"
	actionBtn.AnchorPoint = Vector2.new(1, 1)
	actionBtn.Position = UDim2.new(1, -8, 1, -8)
	actionBtn.Size = UDim2.fromOffset(140, 28)
	actionBtn.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
	actionBtn.TextColor3 = Color3.new(1, 1, 1)
	actionBtn.TextSize = 14
	actionBtn.Font = Enum.Font.GothamBold
	actionBtn.Visible = false
	actionBtn.Parent = frame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = actionBtn

	hintGui = screen
	return screen
end

local function showZoneHint(payload)
	local gui = ensureHintGui()
	local panel = gui.Panel

	if not payload then
		panel.Visible = false
		currentZone = nil
		return
	end

	currentZone = payload.zoneId
	panel.Title.Text = payload.name
	panel.Hint.Text = payload.hint

	local btn = panel.ActionButton
	if payload.actionLabel then
		btn.Text = payload.actionLabel
		btn.Visible = true
	else
		btn.Visible = false
	end

	panel.Visible = true
end

local function performZoneAction()
	if not currentZone then return end
	if currentZone == "arena" then
		Remotes.EnterArena:FireServer()
	elseif currentZone == "beyLab" then
		Remotes.OpenBeySelect:FireServer()
		local select = player.PlayerGui:FindFirstChild("BeySelect")
		if select then
			select.Enabled = true
		end
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZoneHint)

ensureHintGui().Panel.ActionButton.MouseButton1Click:Connect(performZoneAction)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		performZoneAction()
	end
end)
