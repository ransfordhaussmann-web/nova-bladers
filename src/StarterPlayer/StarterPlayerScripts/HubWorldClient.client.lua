local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui

local function ensureHintGui()
	if hintGui then return hintGui end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HubHints"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -80)
	label.Size = UDim2.new(0, 320, 0, 48)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 18
	label.Font = Enum.Font.GothamMedium
	label.Text = ""
	label.Visible = false
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	hintGui = label
	return label
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(zoneName, hintText)
	local label = ensureHintGui()
	label.Text = string.format("%s — %s", zoneName, hintText)
	label.Visible = true
	task.delay(3, function()
		if label.Text == string.format("%s — %s", zoneName, hintText) then
			label.Visible = false
		end
	end)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
