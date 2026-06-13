local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true

local function ensureWalkHint()
	local gui = player.PlayerGui:FindFirstChild("HubWalkHint")
	if gui then return gui end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubWalkHint"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player.PlayerGui

	local label = Instance.new("TextLabel")
	label.Name = "Hint"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -24)
	label.Size = UDim2.new(0, 420, 0, 48)
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.Text = "Laufe zu einer Zone: Arena-Tor · Bey-Werkstatt · Statuen-Halle"
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return gui
end

local function setWalkHintVisible(visible)
	local gui = ensureWalkHint()
	gui.Enabled = visible
end

Remotes.HubState.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	setWalkHintVisible(inHub)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

setWalkHintVisible(true)
