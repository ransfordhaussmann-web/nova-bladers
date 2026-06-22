local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZoneId: string? = nil
local currentHint = ""

local function getOrCreateHintGui(): ScreenGui
	local gui = player.PlayerGui:FindFirstChild("HubZoneHint")
	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubZoneHint"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "Bar"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -24)
	frame.Size = UDim2.fromOffset(420, 44)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(240, 240, 250)
	label.TextSize = 16
	label.Parent = frame

	return gui
end

local hintGui = getOrCreateHintGui()
local hintBar = hintGui.Bar
local hintLabel = hintBar.HintLabel

local function updateHintDisplay()
	if currentHint ~= "" and currentZoneId then
		hintLabel.Text = currentHint
		hintBar.Visible = true
	else
		hintBar.Visible = false
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	currentZoneId = payload.zoneId
	currentHint = payload.hint or ""
	updateHintDisplay()
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local function tryZoneAction()
	if not currentZoneId then
		return
	end
	Remotes.HubZoneAction:FireServer(currentZoneId)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)

-- Mobile: tap hint bar to trigger zone action
hintBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		tryZoneAction()
	end
end)
