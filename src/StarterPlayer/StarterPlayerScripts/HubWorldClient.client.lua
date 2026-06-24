local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function getOrCreateHintGui()
	local gui = player.PlayerGui:FindFirstChild("HubZoneHint")
	if gui then return gui end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubZoneHint"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player.PlayerGui

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0.92, 0)
	label.Size = UDim2.fromOffset(520, 56)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(240, 240, 250)
	label.TextSize = 20
	label.TextWrapped = true
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	return gui
end

local hintGui = getOrCreateHintGui()
local hintLabel = hintGui.HintLabel
local hintToken = 0

local function showHint(text, duration)
	duration = duration or 4
	hintToken += 1
	local token = hintToken

	hintLabel.Text = text
	hintGui.Enabled = true

	task.delay(duration, function()
		if token == hintToken then
			hintGui.Enabled = false
		end
	end)
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(text)
	showHint(text, 5)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
		showHint("Wähle deinen Bey im Labor", 4)
	else
		showHint("Bey-Auswahl öffnet sich nach dem Arena-Betritt", 4)
	end
end)
