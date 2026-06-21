local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

local INTERACT_KEY = Enum.KeyCode.E

local function getOrCreateHintGui()
	local gui = player.PlayerGui:FindFirstChild("HubZoneHint")
	if gui then return gui end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubZoneHint"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -80)
	frame.Size = UDim2.new(0, 360, 0, 90)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BackgroundTransparency = 0.15
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
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Text = ""
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -20, 0, 32)
	hint.Position = UDim2.new(0, 10, 0, 48)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.fromRGB(220, 220, 230)
	hint.TextScaled = true
	hint.Font = Enum.Font.Gotham
	hint.Text = ""
	hint.Parent = frame

	return gui
end

local hintGui = getOrCreateHintGui()
local panel = hintGui.Panel
local currentAction = nil

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload.visible then
		panel.Title.Text = payload.name or ""
		panel.Hint.Text = payload.hint or ""
		currentAction = payload.action
		hintGui.Enabled = true
	else
		currentAction = nil
		hintGui.Enabled = false
	end
end)

local function onInteract()
	if not currentAction then return end
	if currentAction == "arena" then
		Remotes.EnterArena:FireServer()
	elseif currentAction == "beySelect" then
		local select = player.PlayerGui:FindFirstChild("BeySelect")
		if select then
			select.Enabled = true
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == INTERACT_KEY then
		onInteract()
	end
end)