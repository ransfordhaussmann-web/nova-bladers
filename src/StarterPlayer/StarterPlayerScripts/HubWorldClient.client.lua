local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui

local function ensureHintGui()
	if hintGui then
		return hintGui
	end

	hintGui = Instance.new("ScreenGui")
	hintGui.Name = "HubZoneHint"
	hintGui.ResetOnSpawn = false
	hintGui.DisplayOrder = 20
	hintGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "HintFrame"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.92, 0)
	frame.Size = UDim2.fromOffset(360, 48)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BackgroundTransparency = 0.2
	frame.Visible = false
	frame.Parent = hintGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(235, 235, 250)
	label.Parent = frame

	return hintGui
end

local function showHint(text)
	local gui = ensureHintGui()
	local frame = gui.HintFrame
	local label = frame.HintLabel

	label.Text = text
	frame.Visible = true
	frame.BackgroundTransparency = 0.2

	local fadeOut = TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.5), {
		BackgroundTransparency = 1,
	})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		frame.Visible = false
		frame.BackgroundTransparency = 0.2
	end)
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload and payload.hint then
		showHint(payload.hint)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local beySelect = playerGui:FindFirstChild("BeySelect")
	if beySelect then
		beySelect.Enabled = true
	end
end)
