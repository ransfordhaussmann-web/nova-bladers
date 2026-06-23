local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeHint = nil
local hintGui

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -80)
	frame.Size = UDim2.fromOffset(320, 72)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 28)
	title.Position = UDim2.fromOffset(8, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -16, 0, 22)
	hint.Position = UDim2.fromOffset(8, 34)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(180, 185, 200)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	local action = Instance.new("TextLabel")
	action.Name = "Action"
	action.Size = UDim2.new(1, -16, 0, 18)
	action.Position = UDim2.fromOffset(8, 52)
	action.BackgroundTransparency = 1
	action.Font = Enum.Font.GothamMedium
	action.TextSize = 13
	action.TextColor3 = Color3.fromRGB(120, 200, 255)
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.Parent = frame

	hintGui = screen
	return screen
end

local function showHint(payload)
	local gui = ensureHintGui()
	gui.Panel.Title.Text = payload.name or "Zone"
	gui.Panel.Hint.Text = payload.hint or ""
	gui.Panel.Action.Text = "[E] Interagieren"
	gui.Enabled = true
	activeHint = payload
end

local function hideHint()
	if hintGui then
		hintGui.Enabled = false
	end
	activeHint = nil
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local function tryZoneAction()
	if not activeHint or not activeHint.action then return end
	Remotes.HubZoneAction:FireServer(activeHint.action)
	if activeHint.action == "EnterArena" then
		hideHint()
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)

player.CharacterRemoving:Connect(hideHint)
