local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
hintLabel.Size = UDim2.new(0.5, 0, 0.06, 0)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.25
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextScaled = true
hintLabel.Font = Enum.Font.Gotham
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

Remotes.HubZoneHint.OnClientEvent:Connect(function(text)
	if text and text ~= "" then
		hintLabel.Text = text
		hintGui.Enabled = true
	else
		hintGui.Enabled = false
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local function connectZonePrompts()
	local hub = workspace:WaitForChild("NovaHub", 30)
	if not hub then return end

	local zones = hub:WaitForChild("Zones", 10)
	if not zones then return end

	for _, zoneFolder in zones:GetChildren() do
		local platform = zoneFolder:FindFirstChild("Platform")
		local prompt = platform and platform:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function()
				Remotes.HubZoneAction:FireServer(zoneFolder.Name)
			end)
		end
	end
end

task.spawn(connectZonePrompts)
